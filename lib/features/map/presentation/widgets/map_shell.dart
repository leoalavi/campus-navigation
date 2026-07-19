import 'package:flutter/material.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_mode_toggle.dart';
import 'package:mq_journey/shared/widgets/glass_pane.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';

class MapShell extends StatelessWidget {
  const MapShell({
    super.key,
    required this.mapView,
    required this.onCenterOnLocation,
    required this.onOpenSearch,
    this.onOpenOverlayPicker,
    this.banner,
    this.footer,
    this.onFooterDismiss,
    this.filterChips,
    this.mapMode,
    this.onMapModeChanged,
    this.arContent,
    this.showArModeToggle = true,
  });

  final Widget mapView;
  final VoidCallback onCenterOnLocation;
  final VoidCallback onOpenSearch;
  final VoidCallback? onOpenOverlayPicker;
  final Widget? banner;
  final Widget? footer;

  /// Called when the user drags/flings the footer panel down past the
  /// dismiss threshold (bottom-sheet behaviour).
  final VoidCallback? onFooterDismiss;
  final Widget? filterChips;
  final MapMode? mapMode;
  final ValueChanged<MapMode>? onMapModeChanged;
  final Widget? arContent;

  /// Whether to float the Campus Map / AR toggle over AR content. Set false
  /// when the AR content is a full page that already owns the top bar (e.g.
  /// the selected-building indoor preview, whose AppBar shows the location
  /// name) — otherwise the floating toggle overlaps that title.
  final bool showArModeToggle;

  static const double _bottomControlsReservedHeight = 80;
  static const double _topOverlayHeight = 180;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerWidget = banner;
    final footerWidget = footer;
    final isCampusMap = mapMode == null || mapMode == MapMode.campusMap;

    return Stack(
      children: [
        Positioned.fill(child: isCampusMap ? mapView : (arContent ?? mapView)),

        if (isCampusMap) ...[
          Positioned(
            top: safeTop + MqSpacing.space4,
            left: MqSpacing.space4,
            right: MqSpacing.space4,
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: l10n.searchBuildingsPlaceholder,
                  child: GestureDetector(
                    onTap: onOpenSearch,
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

                if (mapMode != null && onMapModeChanged != null) ...[
                  const SizedBox(height: MqSpacing.space3),
                  MapModeToggle(value: mapMode!, onChanged: onMapModeChanged!),
                ],

                if (filterChips != null) ...[
                  const SizedBox(height: MqSpacing.space3),
                  filterChips!,
                ],

                const SizedBox(height: MqSpacing.space3),

                if (bannerWidget != null) ...[
                  const SizedBox(height: MqSpacing.space3),
                  bannerWidget,
                ],
              ],
            ),
          ),

          if (footerWidget != null)
            Positioned(
              bottom: safeBottom + _bottomControlsReservedHeight,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  MqSpacing.space4,
                  0,
                  MqSpacing.space4,
                  MqSpacing.space2,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height -
                        safeTop -
                        safeBottom -
                        _bottomControlsReservedHeight -
                        _topOverlayHeight -
                        MqSpacing.space4 -
                        MqSpacing.space3 -
                        MqSpacing.space2,
                  ),
                  child: _DraggableFooter(
                    onDismiss: onFooterDismiss,
                    child: footerWidget,
                  ),
                ),
              ),
            ),

          if (onOpenOverlayPicker != null)
            PositionedDirectional(
              start: MqSpacing.space4,
              bottom: safeBottom + MqSpacing.space4,
              child: _GlassIconButton(
                isDark: isDark,
                icon: Icons.layers_outlined,
                tooltip: l10n.mapLayers,
                onPressed: onOpenOverlayPicker!,
              ),
            ),

          PositionedDirectional(
            end: MqSpacing.space4,
            bottom: safeBottom + MqSpacing.space4,
            child: _BrandCircleButton(
              icon: Icons.my_location,
              tooltip: l10n.centerOnLocation,
              onPressed: onCenterOnLocation,
            ),
          ),
        ],

        // In AR mode the campus overlay above is hidden, so surface the mode
        // toggle on its own — otherwise there is no way back to Campus Map.
        if (!isCampusMap &&
            showArModeToggle &&
            mapMode != null &&
            onMapModeChanged != null)
          Positioned(
            top: safeTop + MqSpacing.space4,
            left: MqSpacing.space4,
            right: MqSpacing.space4,
            child: Align(
              alignment: Alignment.topCenter,
              child: MapModeToggle(
                value: mapMode!,
                onChanged: onMapModeChanged!,
              ),
            ),
          ),
      ],
    );
  }
}

class _GlassPane extends GlassPane {
  const _GlassPane({required super.isDark, required super.child});
}

/// Makes the map's footer panel behave like a real bottom sheet: the user
/// can drag it down (touch or mouse — plain drag recognizers accept both)
/// and either fling/drag past the threshold to dismiss it, or release to
/// have it spring back. Drags that start on the panel's inner scrollables
/// stay with the list (the child wins the gesture arena there), so the
/// natural grab area is the handle/header — matching standard sheets.
class _DraggableFooter extends StatefulWidget {
  const _DraggableFooter({required this.child, this.onDismiss});

  final Widget child;
  final VoidCallback? onDismiss;

  @override
  State<_DraggableFooter> createState() => _DraggableFooterState();
}

class _DraggableFooterState extends State<_DraggableFooter>
    with SingleTickerProviderStateMixin {
  // Built eagerly in initState (not via a lazy `late final` field
  // initializer) so the controller always exists by the time dispose()
  // runs. A lazy initializer only constructs the controller on first
  // *access* — if the panel is removed (building deselected, browse
  // group cleared, etc.) before the user ever drags it, dispose() would
  // be that first access, and creating a ticker that late tries to look
  // up TickerMode on an already-deactivated element, crashing with
  // "Looking up a deactivated widget's ancestor is unsafe."
  late final AnimationController _settle;

  Tween<double> _settleTween = Tween(begin: 0, end: 0);
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _settle =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(
          () => setState(() => _offset = _settleTween.evaluate(_settle)),
        );
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _settle.stop();
    setState(() {
      // Only allow downward translation; upward just returns to rest.
      _offset = (_offset + details.delta.dy).clamp(0.0, double.infinity);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final panelHeight = context.size?.height ?? 240;
    final flungDown =
        details.primaryVelocity != null && details.primaryVelocity! > 700;
    final draggedFar = _offset > panelHeight * 0.35;
    if ((flungDown || draggedFar) && widget.onDismiss != null) {
      widget.onDismiss!();
      // The panel unmounts when state clears; reset for the next one.
      _offset = 0;
      return;
    }
    _settleTween = Tween(begin: _offset, end: 0);
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, _offset),
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        onVerticalDragCancel: () {
          _settleTween = Tween(begin: _offset, end: 0);
          _settle.forward(from: 0);
        },
        child: widget.child,
      ),
    );
  }
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
    return GlassSurface(
      variant: GlassVariant.control,
      borderRadius: BorderRadius.circular(999), // stadium/circle
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: isDark ? Colors.white : MqColors.black87),
          iconSize: 26,
          padding: const EdgeInsets.all(14),
          tooltip: tooltip,
          onPressed: onPressed,
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
