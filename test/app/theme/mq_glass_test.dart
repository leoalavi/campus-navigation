import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_glass.dart';

void main() {
  test('opacity is more transparent in dark mode', () {
    expect(
      MqGlass.opacityRegular(true),
      lessThan(MqGlass.opacityRegular(false)),
    );
  });

  test('content and high-contrast opacities never depend on backdrop', () {
    expect(MqGlass.opacityContent, greaterThanOrEqualTo(0.92));
    expect(MqGlass.opacityHighContrast, greaterThanOrEqualTo(0.92));
  });

  test('alpha tokens are within [0,1]', () {
    for (final isDark in [false, true]) {
      for (final a in [
        MqGlass.borderAlpha(isDark),
        MqGlass.shadowAlpha(isDark),
        MqGlass.specularAlpha(isDark),
        MqGlass.opacityRegular(isDark),
      ]) {
        expect(a, inInclusiveRange(0.0, 1.0));
      }
    }
  });

  test('geometry + shader tokens have expected values', () {
    expect(MqGlass.radiusBar, 18);
    expect(MqGlass.radiusFloating, 22);
    expect(MqGlass.blurMd, 18);
    expect(MqGlass.refractiveIndex, 1.5);
    expect(MqGlass.rimWidth, 24);
    expect(MqGlass.aberration, 0.02);
  });

  test('tint is white in light mode and charcoal in dark mode', () {
    expect(MqGlass.tint(false), const Color(0xFFFFFFFF));
    expect(MqGlass.tint(true), MqColors.charcoal800);
  });
}
