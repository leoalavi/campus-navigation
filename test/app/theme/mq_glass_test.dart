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

  test('geometry + shader tokens are sane (tunable values in range)', () {
    // Structural radii/blur are stable.
    expect(MqGlass.radiusBar, 18);
    expect(MqGlass.radiusFloating, 22);
    expect(MqGlass.blurMd, greaterThan(0));
    // Shader params are tuned by feel; assert physically-sane ranges rather
    // than exact magic numbers so tuning doesn't break the suite.
    expect(MqGlass.refractiveIndex, inInclusiveRange(1.0, 2.5));
    expect(MqGlass.rimWidth, greaterThan(0));
    expect(MqGlass.aberration, inInclusiveRange(0.0, 0.2));
    expect(MqGlass.refractIntensity, inInclusiveRange(0.0, 2.0));
    expect(MqGlass.fresnel, inInclusiveRange(0.0, 1.0));
    expect(MqGlass.glare, inInclusiveRange(0.0, 1.0));
  });

  test('tint is white in light mode and charcoal in dark mode', () {
    expect(MqGlass.tint(false), const Color(0xFFFFFFFF));
    expect(MqGlass.tint(true), MqColors.charcoal800);
  });
}
