import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/theme/mq_glass.dart';

/// Contrast floors for text drawn ON a glass surface.
///
/// Glass is only ~0.45–0.52 opaque, so on-glass labels composite against the
/// tint *plus* the campus photo behind it. The map search pill's placeholder
/// used to be `charcoal800 @ alpha 0.4`, which measured about 2:1 against its
/// own pill — these tests stop anything drifting back to that.

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Composites [fg] (with its alpha) over an opaque [bg].
Color _over(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

/// The effective pill backdrop: the glass tint at its real opacity over a
/// mid-tone campus photo (the realistic worst case for light mode).
Color _pillBackdrop(bool isDark) {
  const photo = Color(0xFF787878);
  final tint = MqGlass.tint(isDark).withValues(
    alpha: MqGlass.opacityRegular(isDark),
  );
  return _over(tint, photo);
}

void main() {
  group('on-glass content tokens', () {
    for (final isDark in [false, true]) {
      final mode = isDark ? 'dark' : 'light';

      test('$mode: secondary label clears AA body contrast on the pill', () {
        final bg = _pillBackdrop(isDark);
        final fg = _over(MqGlass.onGlassSecondary(isDark), bg);
        expect(
          _contrast(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'search placeholder must be readable over glass in $mode',
        );
      });

      test('$mode: primary label is at least as strong as secondary', () {
        final bg = _pillBackdrop(isDark);
        final primary = _contrast(_over(MqGlass.onGlassPrimary(isDark), bg), bg);
        final secondary = _contrast(
          _over(MqGlass.onGlassSecondary(isDark), bg),
          bg,
        );
        expect(
          primary,
          greaterThanOrEqualTo(secondary),
          reason: 'hierarchy: active labels must not be weaker than muted ones',
        );
      });

      test('$mode: icons stay visible without matching text weight', () {
        final bg = _pillBackdrop(isDark);
        final icon = _contrast(_over(MqGlass.onGlassIcon(isDark), bg), bg);
        expect(icon, greaterThanOrEqualTo(3.0), reason: 'AA non-text minimum');
        expect(
          icon,
          lessThanOrEqualTo(
            _contrast(_over(MqGlass.onGlassSecondary(isDark), bg), bg),
          ),
          reason: 'icons support the label rather than competing with it',
        );
      });
    }

    test('glass stays translucent — readability came from the content', () {
      // Guards the constraint that the fix must not solidify the surface.
      expect(MqGlass.opacityRegular(false), lessThan(0.7));
      expect(MqGlass.opacityRegular(true), lessThan(0.7));
    });
  });
}
