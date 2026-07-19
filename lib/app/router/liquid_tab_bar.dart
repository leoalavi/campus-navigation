import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Per-icon flourish played when a tab becomes selected.
enum TabFx { bounce, rotateOpen, pulse, spin }

/// One destination of the [LiquidTabBar].
class LiquidNavItem {
  const LiquidNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.fx,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final TabFx fx;
}

/// A custom glass tab bar with a metaball "lens" indicator you can tap OR
/// press-and-drag across the tabs (the lens follows your finger and stretches
/// like liquid), plus gel-press physics and per-icon flourishes.
class LiquidTabBar extends StatefulWidget {
  const LiquidTabBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.items,
    required this.color,
    this.height = 66,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<LiquidNavItem> items;
  final Color color;
  final double height;

  @override
  State<LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<LiquidTabBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  // Indicator position in index-space (0..n-1). It lerps _fracFrom -> _fracTo
  // via [_slide], unless a drag is in progress (then _dragFrac overrides).
  late double _fracFrom = widget.currentIndex.toDouble();
  late double _fracTo = widget.currentIndex.toDouble();
  double? _dragFrac;
  int? _pressed;

  double get _displayFrac {
    if (_dragFrac != null) return _dragFrac!;
    final t = Curves.easeInOutCubic.transform(_slide.value);
    return _fracFrom + (_fracTo - _fracFrom) * t;
  }

  void _animateTo(double target) {
    _fracFrom = _displayFrac;
    _fracTo = target;
    _slide.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant LiquidTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate to a new selection unless we're mid-drag (drag drives it live).
    if (oldWidget.currentIndex != widget.currentIndex && _dragFrac == null) {
      _animateTo(widget.currentIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  int _indexAt(double dx, double slot, int n) =>
      (dx / slot).floor().clamp(0, n - 1);

  double _fracAt(double dx, double slot, int n) =>
      (dx / slot - 0.5).clamp(0.0, (n - 1).toDouble());

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final slot = w / n;
        final indH = widget.height * 0.78; // tall enough to hold icon + label

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) =>
              setState(() => _pressed = _indexAt(d.localPosition.dx, slot, n)),
          onTapCancel: () => setState(() => _pressed = null),
          onTapUp: (d) {
            final i = _indexAt(d.localPosition.dx, slot, n);
            setState(() => _pressed = null);
            widget.onSelected(i);
          },
          onHorizontalDragStart: (d) => setState(() {
            _pressed = _indexAt(d.localPosition.dx, slot, n);
            _dragFrac = _fracAt(d.localPosition.dx, slot, n);
          }),
          onHorizontalDragUpdate: (d) {
            final i = _indexAt(d.localPosition.dx, slot, n);
            setState(() {
              _dragFrac = _fracAt(d.localPosition.dx, slot, n);
              _pressed = i;
            });
            if (i != widget.currentIndex) widget.onSelected(i);
          },
          onHorizontalDragEnd: (_) {
            final target = widget.currentIndex.toDouble();
            _fracFrom = _dragFrac ?? target;
            _fracTo = target;
            setState(() {
              _dragFrac = null;
              _pressed = null;
            });
            _slide.forward(from: 0);
          },
          child: SizedBox(
            height: widget.height,
            child: AnimatedBuilder(
              animation: _slide,
              builder: (context, _) {
                final frac = _displayFrac;
                final indicatorCenter = (frac + 0.5) * slot;
                final animStretch = _dragFrac == null
                    ? math.sin(math.pi * _slide.value) * slot * 0.5
                    : slot * 0.22; // fatter, "grabbed" while dragging
                final indW = slot * 0.72 + animStretch;
                return Stack(
                  children: [
                    Positioned(
                      left: indicatorCenter - indW / 2,
                      top: (widget.height - indH) / 2,
                      width: indW,
                      height: indH,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(indH / 2),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (int i = 0; i < n; i++)
                          Expanded(child: _buildTab(i)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab(int i) {
    final item = widget.items[i];
    final selected = i == widget.currentIndex;
    final pressed = _pressed == i;
    // Touch (tap + drag) is handled by the parent GestureDetector; here we only
    // declare accessibility semantics so VoiceOver announces each tab + state.
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      onTap: () => widget.onSelected(i),
      // Icon + label are one centred group so they both sit inside the lens.
      child: Center(
        child: AnimatedScale(
          scale: pressed ? 0.85 : 1.0, // gel-press
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabIcon(item: item, selected: selected, color: widget.color),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tab's icon, which plays its [TabFx] whenever it becomes selected.
class _TabIcon extends StatefulWidget {
  const _TabIcon({
    required this.item,
    required this.selected,
    required this.color,
  });

  final LiquidNavItem item;
  final bool selected;
  final Color color;

  @override
  State<_TabIcon> createState() => _TabIconState();
}

class _TabIconState extends State<_TabIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void initState() {
    super.initState();
    if (widget.selected) _c.value = 1;
  }

  @override
  void didUpdateWidget(covariant _TabIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _c.forward(from: 0);
    } else if (!widget.selected && oldWidget.selected) {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: Icon(
        widget.selected ? widget.item.activeIcon : widget.item.icon,
        color: widget.color,
        size: 25,
      ),
      builder: (context, child) {
        final t = _c.value;
        double scale = 1.0, angle = 0.0;
        switch (widget.item.fx) {
          case TabFx.spin:
            angle = 2 * math.pi * Curves.easeOutCubic.transform(t);
            scale = 0.82 + 0.18 * Curves.easeOutBack.transform(t);
          case TabFx.rotateOpen:
            angle = 0.25 * 2 * math.pi * Curves.easeOutBack.transform(t);
            scale = 0.82 + 0.18 * Curves.easeOutBack.transform(t);
          case TabFx.bounce:
            // Pure spring scale — no vertical jump (keeps it inside the lens).
            scale = 0.78 + 0.24 * Curves.elasticOut.transform(t);
          case TabFx.pulse:
            scale = 1.0 + 0.22 * math.sin(math.pi * t);
        }
        return Transform.rotate(
          angle: angle,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}
