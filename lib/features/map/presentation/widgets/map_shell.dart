import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_mode_toggle.dart';
import 'package:mq_journey/shared/widgets/glass_pane.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';

class MapShell extends StatefulWidget {
  const MapShell({
    super.key,
    required this.mapView,
    required this.onCenterOnLocation,
    required this.onOpenSearch,
    this.onOpenOverlayPicker,
    this.banner,
    this.footer,
    this.onFooterDismiss,
    this.footerSnappable = false,
    this.footerResetKey,
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

  /// Enables the peek/medium/expanded snap states on the footer (used for
  /// the category/browse result lists; the compact building-info card
  /// keeps plain drag-to-dismiss).
  final bool footerSnappable;

  /// Identity of the footer's content; when it changes the snapping sheet
  /// reopens to its medium size (see [_DraggableFooter.resetKey]).
  final Object? footerResetKey;
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
  State<MapShell> createState() => _MapShellState();
}

class _MapShellState extends State<MapShell> {
  /// Live rendered height of the footer sheet. The layers / my-location
  /// controls listen to this and ride just above the sheet's top edge —
  /// Google-Maps style — instead of sitting at a fixed bottom offset that
  /// the sheet slides behind.
  final ValueNotifier<double> _sheetHeight = ValueNotifier<double>(0);

  // Forwarding getters keep the (large) build body unchanged after the
  // Stateless → Stateful conversion.
  Widget get mapView => widget.mapView;
  VoidCallback get onCenterOnLocation => widget.onCenterOnLocation;
  VoidCallback get onOpenSearch => widget.onOpenSearch;
  VoidCallback? get onOpenOverlayPicker => widget.onOpenOverlayPicker;
  Widget? get banner => widget.banner;
  Widget? get footer => widget.footer;
  VoidCallback? get onFooterDismiss => widget.onFooterDismiss;
  bool get footerSnappable => widget.footerSnappable;
  Object? get footerResetKey => widget.footerResetKey;
  Widget? get filterChips => widget.filterChips;
  MapMode? get mapMode => widget.mapMode;
  ValueChanged<MapMode>? get onMapModeChanged => widget.onMapModeChanged;
  Widget? get arContent => widget.arContent;
  bool get showArModeToggle => widget.showArModeToggle;

  static const double _bottomControlsReservedHeight =
      MapShell._bottomControlsReservedHeight;
  static const double _topOverlayHeight = MapShell._topOverlayHeight;

  @override
  void dispose() {
    _sheetHeight.dispose();
    super.dispose();
  }

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
              // The sheet now sits just above the bottom nav; the layers /
              // locate controls ride ABOVE its top edge (see below) rather
              // than living in a reserved strip underneath it.
              bottom: safeBottom + MqSpacing.space2,
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
                    snappable: footerSnappable,
                    resetKey: footerResetKey,
                    heightListenable: _sheetHeight,
                    child: footerWidget,
                  ),
                ),
              ),
            ),

          // Layers + my-location controls. With a footer open they track the
          // sheet's live rendered height so they always float a fixed gap
          // above its top edge — collapsing/expanding carries them along.
          if (onOpenOverlayPicker != null)
            ValueListenableBuilder<double>(
              valueListenable: _sheetHeight,
              child: _GlassIconButton(
                isDark: isDark,
                icon: Icons.layers_outlined,
                tooltip: l10n.mapLayers,
                onPressed: onOpenOverlayPicker!,
              ),
              builder: (context, sheetH, child) => PositionedDirectional(
                start: MqSpacing.space4,
                bottom: footerWidget == null
                    ? safeBottom + MqSpacing.space4
                    : safeBottom +
                          MqSpacing.space2 +
                          MqSpacing.space2 +
                          sheetH +
                          MqSpacing.space3,
                child: child!,
              ),
            ),

          ValueListenableBuilder<double>(
            valueListenable: _sheetHeight,
            child: _BrandCircleButton(
              icon: Icons.my_location,
              tooltip: l10n.centerOnLocation,
              onPressed: onCenterOnLocation,
            ),
            builder: (context, sheetH, child) => PositionedDirectional(
              end: MqSpacing.space4,
              bottom: footerWidget == null
                  ? safeBottom + MqSpacing.space4
                  : safeBottom +
                        MqSpacing.space2 +
                        MqSpacing.space2 +
                        sheetH +
                        MqSpacing.space3,
              child: child!,
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

/// Makes the map's footer panel behave like a real bottom sheet.
///
/// Two modes:
///  • [snappable] = false (compact building-info card): drag down to
///    dismiss, spring back otherwise — the card is intrinsic-height and
///    small, so resize states add nothing.
///  • [snappable] = true (category/browse result lists): the sheet snaps
///    between three heights — peek (handle + header only, most of the map
///    visible), medium, and expanded — driven by drag or fling, on touch
///    AND mouse (plain drag recognizers accept both; scrollables don't
///    claim mouse drags on web, so click-dragging even over the list
///    resizes the sheet while the wheel still scrolls it). A downward
///    fling at peek dismisses. Accessible fallback actions (expand /
///    collapse / dismiss) are exposed as custom semantics actions using
///    MaterialLocalizations so they are localized for free.
///
/// Drags that start on the panel's inner scrollables stay with the list on
/// touch (the child wins the gesture arena there), so the natural touch
/// grab area is the handle/header — matching standard sheets.
class _DraggableFooter extends StatefulWidget {
  const _DraggableFooter({
    required this.child,
    this.onDismiss,
    this.snappable = false,
    this.resetKey,
    this.heightListenable,
  });

  final Widget child;
  final VoidCallback? onDismiss;

  /// Written with the sheet's live *visual* height after every layout /
  /// drag frame so companion widgets (the floating map controls) can ride
  /// the sheet's top edge.
  final ValueNotifier<double>? heightListenable;

  /// Enables peek/medium/expanded snap states (browse/category panels).
  final bool snappable;

  /// When this changes (e.g. the user picked a different category), the
  /// sheet animates back to the medium size so fresh content is visible
  /// even if the previous list was collapsed to peek.
  final Object? resetKey;

  @override
  State<_DraggableFooter> createState() => _DraggableFooterState();
}

class _DraggableFooterState extends State<_DraggableFooter>
    with SingleTickerProviderStateMixin {
  /// Peek height: grab handle + one header row stays visible.
  static const double _peek = 100;

  /// Preferred medium height (clamped to the available space).
  static const double _mediumBase = 320;

  /// Current sheet height when [widget.snappable]; null = "use medium".
  double? _height;

  /// Available max height, captured from the surrounding LayoutBuilder.
  double _maxH = 0;

  /// Measured natural height of the current content, when it is shorter
  /// than the height the sheet allows. Caps the expanded snap so short
  /// lists (e.g. Faculty's four rows) can't be dragged into a large empty
  /// glass area. Null = content fills whatever it's given / not measured.
  double? _contentMax;

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
    // Do NOT write to `heightListenable` here. `initState` runs while the
    // framework is still inside the current build pass (element mounting),
    // so a synchronous ValueNotifier write here synchronously calls
    // notifyListeners() on any ALREADY-MOUNTED ValueListenableBuilder (the
    // companion map controls) — which calls setState()/markNeedsBuild() on
    // a widget mid-build. That is exactly the reported
    // "setState() or markNeedsBuild() called during build" crash (widget
    // being built: Positioned; stack: ValueListenableBuilder._valueChanged
    // <- ChangeNotifier.notifyListeners).
    //
    // `build()` below unconditionally schedules `_afterLayout()` via
    // `addPostFrameCallback`, which measures the real height and writes
    // `heightListenable` AFTER the frame — that's the only place this
    // notifier should ever be written from. For the one frame before that
    // callback fires, the controls simply keep their previous position;
    // they correct themselves before the next raster, so nothing is
    // visibly wrong, and no listener is ever notified during a build.
    _settle =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(
          () => setState(() {
            if (widget.snappable) {
              _height = _settleTween.evaluate(_settle);
            } else {
              _offset = _settleTween.evaluate(_settle);
            }
          }),
        );
  }

  @override
  void didUpdateWidget(covariant _DraggableFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New content (different category / group) → forget the previous
    // content's measured height and reopen to medium so the fresh list is
    // actually visible even if the old one was collapsed to peek.
    if (widget.snappable && widget.resetKey != oldWidget.resetKey) {
      _contentMax = null;
      if (_maxH > 0) _animateHeightTo(_medium);
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  /// Hard ceiling: available space, clamped by measured content height so
  /// the sheet never opens past what the content can actually fill.
  double get _effectiveMax {
    final available = _maxH > 0 ? _maxH : 480.0;
    final content = _contentMax;
    if (content == null) return available;
    return content.clamp(_peek, available);
  }

  double get _medium => _mediumBase.clamp(_peek, _effectiveMax);

  List<double> get _snaps {
    final s = <double>{_peek, _medium, _effectiveMax}.toList()..sort();
    return s;
  }

  double get _currentHeight => (_height ?? _medium).clamp(_peek, _effectiveMax);

  /// Post-layout bookkeeping: report the sheet's visual height to
  /// [_DraggableFooter.heightListenable] (companion controls ride it), and
  /// learn the content's natural height for the content-aware max.
  void _afterLayout() {
    if (!mounted) return;
    final rendered = context.size?.height;
    if (rendered == null) return;

    if (widget.snappable) {
      final cap = _currentHeight;
      if (rendered < cap - 2) {
        // Content can't fill the allowed height → its natural height IS
        // the max worth exposing. Snap targets shrink accordingly, and the
        // current height clamps down so no empty glass remains.
        _contentMax = rendered;
        if ((_height ?? cap) > rendered + 1) {
          setState(() => _height = rendered);
        }
      } else {
        // Content fills what it was given — its true height is unknown
        // (≥ cap), so leave the ceiling open.
        _contentMax = null;
      }
      widget.heightListenable?.value = rendered;
    } else {
      // Visual height while drag-to-dismiss translating downward.
      widget.heightListenable?.value = (rendered - _offset).clamp(
        0.0,
        rendered,
      );
    }
  }

  void _animateHeightTo(double target) {
    _settleTween = Tween(begin: _currentHeight, end: target);
    _settle.forward(from: 0);
  }

  void _snapStep(int direction) {
    final h = _currentHeight;
    final snaps = _snaps;
    if (direction > 0) {
      _animateHeightTo(snaps.where((s) => s > h + 1).firstOrNull ?? snaps.last);
    } else {
      final below = snaps.where((s) => s < h - 1).lastOrNull;
      if (below == null) return; // already at peek
      _animateHeightTo(below);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _settle.stop();
    setState(() {
      if (widget.snappable) {
        _height = (_currentHeight - details.delta.dy).clamp(
          _peek,
          _effectiveMax,
        );
      } else {
        // Only allow downward translation; upward just returns to rest.
        _offset = (_offset + details.delta.dy).clamp(0.0, double.infinity);
      }
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (widget.snappable) {
      final h = _currentHeight;
      if (v > 700) {
        // Downward fling: step down a snap, or dismiss when already at peek.
        final below = _snaps.where((s) => s < h - 1).lastOrNull;
        if (below == null) {
          widget.onDismiss?.call();
          _height = null; // reset for the next panel
          return;
        }
        _animateHeightTo(below);
      } else if (v < -700) {
        _animateHeightTo(
          _snaps.where((s) => s > h + 1).firstOrNull ?? _effectiveMax,
        );
      } else {
        // Settle on the nearest snap size.
        final nearest = _snaps.reduce(
          (a, b) => (a - h).abs() <= (b - h).abs() ? a : b,
        );
        _animateHeightTo(nearest);
      }
      return;
    }

    final panelHeight = context.size?.height ?? 240;
    final flungDown = v > 700;
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

  void _onDragCancel() {
    if (widget.snappable) {
      final h = _currentHeight;
      final nearest = _snaps.reduce(
        (a, b) => (a - h).abs() <= (b - h).abs() ? a : b,
      );
      _animateHeightTo(nearest);
      return;
    }
    _settleTween = Tween(begin: _offset, end: 0);
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Measure after every frame: feeds the companion controls' position and
    // the content-aware max. Safe to re-schedule per build; setState inside
    // is guarded by >1px deltas so it converges instead of looping.
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterLayout());

    if (!widget.snappable) {
      return Transform.translate(
        offset: Offset(0, _offset),
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          onVerticalDragCancel: _onDragCancel,
          child: widget.child,
        ),
      );
    }

    final m = MaterialLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight.isFinite) _maxH = constraints.maxHeight;
        final h = _currentHeight;
        return Semantics(
          container: true,
          customSemanticsActions: {
            // Localized-for-free accessibility fallbacks for drag.
            CustomSemanticsAction(label: m.collapsedIconTapHint): () =>
                _snapStep(1),
            CustomSemanticsAction(label: m.expandedIconTapHint): () =>
                _snapStep(-1),
            if (widget.onDismiss != null)
              CustomSemanticsAction(label: m.closeButtonTooltip): () =>
                  widget.onDismiss!(),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            onVerticalDragCancel: _onDragCancel,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: h),
              child: widget.child,
            ),
          ),
        );
      },
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
