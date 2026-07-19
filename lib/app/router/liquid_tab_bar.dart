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

/// A custom glass tab bar with a metaball "lens" indicator that stretches as it
/// slides between tabs, per-tab gel-press physics, and per-icon flourishes.
class LiquidTabBar extends StatefulWidget {
  const LiquidTabBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.items,
    required this.color,
    this.height = 64,
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
    duration: const Duration(milliseconds: 480),
  );
  late int _from = widget.currentIndex;
  late int _to = widget.currentIndex;
  int? _pressed;

  @override
  void didUpdateWidget(covariant LiquidTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _from = oldWidget.currentIndex;
      _to = widget.currentIndex;
      _slide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final slot = w / n;
        final indH = widget.height * 0.72;
        return SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _slide,
            builder: (context, _) {
              final t = Curves.easeInOutCubic.transform(_slide.value);
              final centerFrac = _from + (_to - _from) * t;
              final indicatorCenter = (centerFrac + 0.5) * slot;
              // Metaball stretch: the lens fattens mid-transition, like liquid.
              final stretch = math.sin(math.pi * _slide.value) * slot * 0.55;
              final indW = slot * 0.74 + stretch;
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
                      for (int i = 0; i < n; i++) Expanded(child: _buildTab(i)),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTab(int i) {
    final item = widget.items[i];
    final selected = i == widget.currentIndex;
    final pressed = _pressed == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = i),
      onTapUp: (_) => setState(() => _pressed = null),
      onTapCancel: () => setState(() => _pressed = null),
      onTap: () => widget.onSelected(i),
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: AnimatedScale(
          // Gel-press: squish on touch, spring back on release.
          scale: pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabIcon(item: item, selected: selected, color: widget.color),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox(height: 0),
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
        size: 26,
      ),
      builder: (context, child) {
        final t = _c.value;
        double scale = 1.0, angle = 0.0, dy = 0.0;
        switch (widget.item.fx) {
          case TabFx.spin:
            angle = 2 * math.pi * Curves.easeOutCubic.transform(t);
            scale = 0.8 + 0.2 * Curves.easeOutBack.transform(t);
          case TabFx.rotateOpen:
            angle = 0.25 * 2 * math.pi * Curves.easeOutBack.transform(t);
            scale = 0.8 + 0.2 * Curves.easeOutBack.transform(t);
          case TabFx.bounce:
            dy = -7.0 * math.sin(math.pi * t); // little jump
            scale = 0.8 + 0.25 * Curves.elasticOut.transform(t);
          case TabFx.pulse:
            scale = 1.0 + 0.32 * math.sin(math.pi * t); // grow then settle
        }
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}
