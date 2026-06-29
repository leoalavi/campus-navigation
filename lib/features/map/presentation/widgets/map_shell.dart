import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_mode_toggle.dart';
import 'package:mq_journey/shared/widgets/glass_pane.dart';
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
    this.filterChips,
    this.mapMode,
    this.onMapModeChanged,
    this.arContent,
  });

  final Widget mapView;
  final VoidCallback onCenterOnLocation;
  final VoidCallback onOpenSearch;
  final VoidCallback? onOpenOverlayPicker;
  final Widget? banner;
  final Widget? footer;
  final Widget? filterChips;
  final MapMode? mapMode;
  final ValueChanged<MapMode>? onMapModeChanged;
  final Widget? arContent;

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
                  child: footerWidget,
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
      ],
    );
  }
}

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
