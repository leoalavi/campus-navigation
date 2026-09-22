import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/app/router/shell_chrome_provider.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/shared/widgets/glass_pane.dart';
import 'package:mq_navigation/app/theme/mq_spacing.dart';
import 'package:mq_navigation/features/map/domain/entities/map_renderer_type.dart';
import 'package:mq_navigation/features/map/presentation/widgets/map_bottom_sheet.dart';
import 'package:mq_navigation/features/map/presentation/widgets/map_mode_toggle.dart';

/// Scaffold overlay for the map screen.
///
/// Wraps the underlying map renderer in a `Stack` to provide floating glass-styled
/// UI components like the search bar, mode toggle, error banners, and the
/// interactive bottom footer (routing panel or search results).
class MapShell extends ConsumerStatefulWidget {
  const MapShell({
    super.key,
    required this.mapView,
    required this.renderer,
    required this.onRendererChanged,
    required this.onCenterOnLocation,
    required this.onOpenSearch,
    this.onOpenOverlayPicker,
    this.banner,
    this.footer,
    this.filterChips,
  });

  final Widget mapView;
  final MapRendererType renderer;
  final ValueChanged<MapRendererType> onRendererChanged;
  final VoidCallback onCenterOnLocation;
  final VoidCallback onOpenSearch;
  final VoidCallback? onOpenOverlayPicker;
  final Widget? banner;
  final Widget? footer;
  final Widget? filterChips;

  @override
  ConsumerState<MapShell> createState() => _MapShellState();
}

class _MapShellState extends ConsumerState<MapShell> {
  /// Live height of the docked sheet, so the floating corner buttons can ride
  /// just above it instead of being buried underneath.
  double _sheetHeight = 0;

  /// Gap held between the docked sheet's top edge and the floating corner
  /// buttons that ride above it.
  static const double _controlsGap = MqSpacing.space3;

  /// Keeps [mapSheetOpenProvider] in step with whether a sheet is docked.
  ///
  /// Written from a post-frame callback: `build` must not mutate providers,
  /// and the shell rebuilds in the same frame this is read.
  void _syncSheetVisibility() {
    final isOpen = widget.footer != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(mapSheetOpenProvider.notifier).set(isOpen);
    });
  }

  /// Captured while the element is still mounted. `dispose()` cannot look up
  /// ancestors (the element tree is already unstable there), so the notifier
  /// is grabbed up front and only *used* on the way out.
  MapSheetOpenNotifier? _sheetNotifier;

  @override
  void initState() {
    super.initState();
    _sheetNotifier = ref.read(mapSheetOpenProvider.notifier);
  }

  @override
  void dispose() {
    // Leaving the Map tab with a sheet open must not strand the nav hidden.
    final notifier = _sheetNotifier;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifier?.set(false));
    super.dispose();
  }

  /// Where the floating corner buttons sit: just above the docked sheet when
  /// one is open, otherwise their normal resting place above the safe area.
  double _controlsBottom(double safeBottom) =>
      _sheetHeight > 0
      ? _sheetHeight + _controlsGap
      : safeBottom + MqSpacing.space4;

  @override
  Widget build(BuildContext context) {
    _syncSheetVisibility();
    final l10n = AppLocalizations.of(context)!;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerWidget = widget.banner;
    final footerWidget = widget.footer;

    return Stack(
      children: [
        // ── Full-bleed map ─────────────────────────────────
        Positioned.fill(child: widget.mapView),

        // ── Top overlay: search bar + widget.renderer toggle ──────
        Positioned(
          top: safeTop + MqSpacing.space4,
          left: MqSpacing.space4,
          right: MqSpacing.space4,
          child: Column(
            children: [
              // Glass search bar
              Semantics(
                button: true,
                label: l10n.searchBuildingsPlaceholder,
                child: GestureDetector(
                  onTap: widget.onOpenSearch,
                  child: _GlassPane(
                    isDark: isDark,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: MqSpacing.space4,
                        vertical: MqSpacing.space4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : MqColors.charcoal800.withValues(alpha: 0.4),
                            size: 20,
                          ),
                          const SizedBox(width: MqSpacing.space3),
                          Expanded(
                            child: Text(
                              l10n.searchBuildingsPlaceholder,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : MqColors.charcoal800.withValues(
                                        alpha: 0.4,
                                      ),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Category filter chips — available in both renderers so students
              // can re-filter the map without going back to the home screen.
              if (widget.filterChips != null) ...[
                const SizedBox(height: MqSpacing.space3),
                widget.filterChips!,
              ],

              const SizedBox(height: MqSpacing.space3),

              // Renderer toggle (centered)
              Center(
                child: MapModeToggle(
                  value: widget.renderer,
                  onChanged: widget.onRendererChanged,
                ),
              ),

              // Error widget.banner
              if (bannerWidget != null) ...[
                const SizedBox(height: MqSpacing.space3),
                bannerWidget,
              ],
            ],
          ),
        ),

        // ── Docked bottom sheet (route panel / category list) ──
        // Flush to the bottom edge like the platform maps apps, so the map
        // above it stays visible and usable. Height is user-draggable.
        if (footerWidget != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MapBottomSheet(
              isDark: isDark,
              onHeightChanged: (height) {
                if (!mounted || height == _sheetHeight) return;
                setState(() => _sheetHeight = height);
              },
              child: footerWidget,
            ),
          ),

        // ── Layers button — bottom-left ────────────────────
        // **Stable anchor:** position is independent of widget.footer state.
        if (widget.renderer == MapRendererType.campus && widget.onOpenOverlayPicker != null)
          PositionedDirectional(
            start: MqSpacing.space4,
            bottom: safeBottom + MqSpacing.space4,
            child: _GlassIconButton(
              isDark: isDark,
              icon: Icons.layers_outlined,
              tooltip: l10n.mapLayers,
              onPressed: widget.onOpenOverlayPicker!,
            ),
          ),

        // ── Location button — bottom-right ─────────────────
        // **Stable anchor:** position is independent of widget.footer state.
        AnimatedPositionedDirectional(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          end: MqSpacing.space4,
          bottom: _controlsBottom(safeBottom),
          child: _BrandCircleButton(
            icon: Icons.my_location,
            tooltip: l10n.centerOnLocation,
            onPressed: widget.onCenterOnLocation,
          ),
        ),
      ],
    );
  }
}

// ── Shared glass-effect components ──────────────────────────

/// Private alias for internal use.
class _GlassPane extends GlassPane {
  const _GlassPane({required super.isDark, required super.child});
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.isDark,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final bool isDark;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: isDark
              ? MqColors.charcoal800.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.8),
          shape: CircleBorder(
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : MqColors.charcoal800.withValues(alpha: 0.08),
            ),
          ),
          child: IconButton(
            icon: Icon(icon, color: isDark ? Colors.white : MqColors.black87),
            tooltip: tooltip,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _BrandCircleButton extends StatelessWidget {
  const _BrandCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MqColors.red,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: MqColors.red.withValues(alpha: 0.4),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
