import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/shared/widgets/glass_tilt.dart';

void main() {
  test('upright phone is not saturated (the old y/9.81 pin bug)', () {
    // Held perfectly upright: gravity runs along the phone's +y axis. The old
    // mapping clamped this pose to 1.0 permanently, freezing the glare.
    final t = glassTiltTarget(0, 9.81, 0);
    expect(t.dx, 0);
    expect(t.dy, closeTo(-0.45, 1e-9)); // pitch 0 minus the rest offset
    expect(t.dy.abs(), lessThan(1.0)); // never pinned at the clamp
  });

  test('flat screen-up maps to positive pitch', () {
    final t = glassTiltTarget(0, 0, 9.81);
    expect(t.dy, closeTo(0.55, 1e-9));
  });

  test('roll is symmetric left/right', () {
    final left = glassTiltTarget(-4.9, 8.5, 0);
    final right = glassTiltTarget(4.9, 8.5, 0);
    expect(left.dx, lessThan(0));
    expect(right.dx, greaterThan(0));
    expect(right.dx, closeTo(-left.dx, 1e-9));
  });

  test('pitch varies monotonically from upright to flat (not stuck)', () {
    double? prev;
    for (var deg = 0; deg <= 90; deg += 15) {
      final rad = deg * math.pi / 180;
      final t = glassTiltTarget(0, 9.81 * math.cos(rad), 9.81 * math.sin(rad));
      if (prev != null) {
        expect(t.dy, greaterThan(prev), reason: 'stalled at $deg°');
      }
      prev = t.dy;
    }
  });

  test('free-fall/garbage sample maps to zero', () {
    expect(glassTiltTarget(0, 0, 0), Offset.zero);
  });
}
