import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/app/theme/mq_spacing.dart';

/// Google-Maps-style sheet docked to the bottom of the map.
///
/// Replaces the previous free-floating panel, which sat ~80dp off the bottom
/// edge with a fixed height estimate and so drifted into the middle of the map
/// on short viewports, covering the thing the user was trying to look at.
///
/// Behaviour mirrors the platform maps apps:
///   * flush to the bottom edge, rounded top corners only;
///   * opens at a compact height and can be dragged up to [_expandedFraction]
///     or back down;
///   * the child owns its own scrolling — the drag gesture lives on the
///     handle/header band, so dragging the sheet never fights a ListView
///     inside it (the nested-scroll trap `DraggableScrollableSheet` sets when
///     its controller isn't threaded into the child);
///   * height is reported through [onHeightChanged] so the map's floating
///     corner buttons can ride above it.
class MapBottomSheet extends StatefulWidget {
  const MapBottomSheet({
    super.key,
    required this.child,
    this.onHeightChanged,
    this.isDark = false,
  });

  final Widget child;
  final ValueChanged<double>? onHeightChanged;
  final bool isDark;

  /// Fraction of the available height the sheet opens at.
  static const double collapsedFraction = 0.38;

  /// Fraction it can be dragged up to.
  static const double _expandedFraction = 0.86;

  /// Below this the sheet is treated as dismissed-to-compact rather than
  /// shrinking to nothing — closing is the caller's job (the X button), so a
  /// stray downward fling must not leave an unusable sliver.
  static const double _minFraction = 0.22;

  @override
  State<MapBottomSheet> createState() => _MapBottomSheetState();
}

class _MapBottomSheetState extends State<MapBottomSheet>
    with SingleTickerProviderStateMixin {
  late double _fraction = MapBottomSheet.collapsedFraction;
  double _dragStartFraction = MapBottomSheet.collapsedFraction;

  void _reportHeight(double available) {
    final onHeightChanged = widget.onHeightChanged;
    if (onHeightChanged == null) return;
    // Deferred: this fires during layout, and the listener repositions other
    // widgets in the same frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onHeightChanged(_fraction * available);
    });
  }

  void _onDragStart(DragStartDetails _) => _dragStartFraction = _fraction;

  void _onDragUpdate(DragUpdateDetails details, double available) {
    if (available <= 0) return;
    setState(() {
      // Dragging up (negative dy) grows the sheet.
      _fraction = (_fraction - details.delta.dy / available).clamp(
        MapBottomSheet._minFraction,
        MapBottomSheet._expandedFraction,
      );
    });
  }

  void _onDragEnd(DragEndDetails details, double available) {
    // Snap to whichever anchor the gesture was heading for, so the sheet
    // never rests at an arbitrary in-between height.
    final velocity = details.velocity.pixelsPerSecond.dy;
    const snapPoints = [
      MapBottomSheet._minFraction,
      MapBottomSheet.collapsedFraction,
      MapBottomSheet._expandedFraction,
    ];

    double target;
    if (velocity.abs() > 400) {
      target = velocity < 0
          ? MapBottomSheet._expandedFraction
          : (_dragStartFraction >= MapBottomSheet._expandedFraction
                ? MapBottomSheet.collapsedFraction
                : MapBottomSheet._minFraction);
    } else {
      target = snapPoints.reduce(
        (a, b) => (a - _fraction).abs() < (b - _fraction).abs() ? a : b,
      );
    }
    setState(() => _fraction = target);
    _reportHeight(available);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Space between the top of the screen and the bottom edge, minus the
    // status bar — the sheet may use a fraction of this, never more.
    final available = media.size.height - media.padding.top;
    _reportHeight(available);

    final height = _fraction * available;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: height,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MqSpacing.radiusXl),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.isDark
                  ? MqColors.charcoal800.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(MqSpacing.radiusXl),
              ),
              border: Border(
                top: BorderSide(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.80),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: MqColors.charcoal800.withValues(
                    alpha: widget.isDark ? 0.34 : 0.12,
                  ),
                  blurRadius: 22,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  // Drag band. Owns the vertical gesture so the list below
                  // keeps its own scrolling intact.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: (d) => _onDragUpdate(d, available),
                    onVerticalDragEnd: (d) => _onDragEnd(d, available),
                    child: Semantics(
                      label: 'Drag to resize',
                      child: SizedBox(
                        height: 28,
                        width: double.infinity,
                        child: Center(
                          child: Container(
                            key: const ValueKey('map-sheet-drag-handle'),
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? Colors.white.withAlpha(45)
                                  : MqColors.charcoal800.withAlpha(35),
                              borderRadius: BorderRadius.circular(
                                MqSpacing.radiusFull,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
