import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Per-icon flourish played when a tab becomes selected. `scanline` is the
/// QR tab's signature move (a laser scans the icon while viewfinder corners
/// lock on); `homecoming` is Home's (spring landing + warm porch-light bloom +
/// sunrise rays bursting from behind the roof).
enum TabFx { bounce, homecoming, rotateOpen, scanline, spin }

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
    this.accent,
    this.height = 66,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<LiquidNavItem> items;
  final Color color;

  /// Highlight colour for fx that read as *light* (the scanline laser and
  /// viewfinder lock). Defaults to [color].
  final Color? accent;
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
                        // Lens tint follows the bar's foreground colour: white
                        // glow on dark glass, smoked glass on light glass — a
                        // white-on-white lens was invisible in light mode.
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(indH / 2),
                          border: Border.all(
                            color: widget.color.withValues(alpha: 0.26),
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
              _TabIcon(
                item: item,
                selected: selected,
                color: widget.color,
                accent: widget.accent ?? widget.color,
              ),
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
    required this.accent,
  });

  final LiquidNavItem item;
  final bool selected;
  final Color color;
  final Color accent;

  @override
  State<_TabIcon> createState() => _TabIconState();
}

class _TabIconState extends State<_TabIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    // Staged signature sequences need room to read as a story.
    duration:
        widget.item.fx == TabFx.scanline || widget.item.fx == TabFx.homecoming
        ? const Duration(milliseconds: 900)
        : const Duration(milliseconds: 620),
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
    final icon = Icon(
      widget.selected ? widget.item.activeIcon : widget.item.icon,
      color: widget.color,
      size: 25,
    );
    if (widget.item.fx == TabFx.scanline) {
      return _ScanlineFx(controller: _c, accent: widget.accent, child: icon);
    }
    if (widget.item.fx == TabFx.homecoming) {
      return _HomecomingFx(controller: _c, accent: widget.accent, child: icon);
    }
    return AnimatedBuilder(
      animation: _c,
      child: icon,
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
          case TabFx.scanline:
          case TabFx.homecoming:
            break; // handled above with their own widgets
        }
        return Transform.rotate(
          angle: angle,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

/// The QR tab's signature flourish, staged like a real scan:
///  1. 0–70%: a glowing laser line sweeps down the icon and back up while
///     viewfinder corner brackets converge from outside ("acquiring").
///  2. ~50–85%: the brackets snap tight with an ease-out-back overshoot
///     ("lock-on").
///  3. 70–100%: laser dies, the icon gives a small success pop, brackets fade.
/// Idle (t == 0 or 1) renders the bare icon — no overlays linger.
class _ScanlineFx extends StatelessWidget {
  const _ScanlineFx({
    required this.controller,
    required this.accent,
    required this.child,
  });

  final AnimationController controller;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, icon) {
        final t = controller.value;
        final active = t > 0 && t < 1;
        // Triangle wave over the first 70%: laser goes down, then back up.
        final phase = (t / 0.7).clamp(0.0, 1.0);
        final sweep = 1.0 - (1.0 - 2.0 * phase).abs();
        final laserOn = active && t < 0.7;
        final lock = Curves.easeOutBack.transform(
          ((t - 0.5) / 0.35).clamp(0.0, 1.0),
        );
        final cornerOpacity = !active
            ? 0.0
            : (t < 0.8 ? 1.0 : (1.0 - t) / 0.2).clamp(0.0, 1.0);
        final pop =
            1.0 + 0.12 * math.sin(math.pi * ((t - 0.7) / 0.3).clamp(0.0, 1.0));
        return SizedBox(
          width: 30,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(scale: pop, child: icon),
              if (active)
                Opacity(
                  opacity: cornerOpacity,
                  child: Transform.scale(
                    scale: 1.45 - 0.45 * lock,
                    child: CustomPaint(
                      size: const Size(30, 28),
                      painter: _ViewfinderPainter(color: accent),
                    ),
                  ),
                ),
              if (laserOn)
                Positioned(
                  top: 2.0 + sweep * 22.0,
                  left: 1,
                  right: 1,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.0),
                          accent,
                          accent.withValues(alpha: 0.0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.85),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Home's signature flourish, staged like a homecoming at dusk:
///  1. 0–60%: the house lands with an elastic spring squash.
///  2. 20–75%: a warm porch-light glow blooms behind it, then breathes out.
///  3. 45–100%: short sunrise rays burst from behind the roof, expanding
///     outward as they fade.
/// Idle (t == 0 or 1) renders the bare icon — no overlays linger.
class _HomecomingFx extends StatelessWidget {
  const _HomecomingFx({
    required this.controller,
    required this.accent,
    required this.child,
  });

  final AnimationController controller;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, icon) {
        final t = controller.value;
        final active = t > 0 && t < 1;
        final spring =
            0.78 +
            0.24 * Curves.elasticOut.transform((t / 0.6).clamp(0.0, 1.0));
        final bloomIn = Curves.easeInOut.transform(
          ((t - 0.2) / 0.35).clamp(0.0, 1.0),
        );
        final bloomOut = Curves.easeIn.transform(
          ((t - 0.75) / 0.25).clamp(0.0, 1.0),
        );
        final glow = active ? bloomIn * (1.0 - bloomOut) : 0.0;
        final rays = Curves.easeOut.transform(
          ((t - 0.45) / 0.55).clamp(0.0, 1.0),
        );
        return SizedBox(
          width: 30,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (glow > 0)
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.42 * glow),
                        accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              Transform.scale(scale: spring, child: icon),
              if (active && rays > 0 && rays < 1)
                CustomPaint(
                  size: const Size(34, 30),
                  painter: _SunrisePainter(progress: rays, color: accent),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Five short rays fanned over the roof, pushing outward as they fade.
class _SunrisePainter extends CustomPainter {
  const _SunrisePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0))
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height * 0.62);
    for (var i = 0; i < 5; i++) {
      // Fan from 160° to 20° above the horizon (over the roof).
      final angle = -math.pi * (20 + 35 * i) / 180;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final inner = 9.0 + 8.0 * progress;
      final len = 4.5 * (1.0 - 0.5 * progress);
      canvas.drawLine(c + dir * inner, c + dir * (inner + len), p);
    }
  }

  @override
  bool shouldRepaint(covariant _SunrisePainter old) =>
      old.progress != progress || old.color != color;
}

/// Four L-shaped viewfinder corner brackets (the camera "focus lock" glyph).
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    const len = 7.0;
    final w = size.width, h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, 0)
        ..lineTo(len, 0),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - len, 0)
        ..lineTo(w, 0)
        ..lineTo(w, len),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h - len)
        ..lineTo(0, h)
        ..lineTo(len, h),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - len, h)
        ..lineTo(w, h)
        ..lineTo(w, h - len),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter old) => old.color != color;
}
