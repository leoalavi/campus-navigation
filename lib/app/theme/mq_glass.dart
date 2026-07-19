import 'package:flutter/widgets.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';

/// Design tokens for the Liquid Glass-inspired ("Glass UI layer") material.
/// See docs/superpowers/specs/2026-07-19-liquid-glass-ui-design.md.
abstract final class MqGlass {
  // Blur (sigma) for the non-shader frost fallback.
  static const double blurMd = 18;

  // Body opacity per rung. Thin enough that refraction/vibrancy show through
  // (the shader compensates legibility with a 1.55× saturation boost and a
  // two-band rim); a milky 0.74 wash was burying every effect in light mode.
  static double opacityRegular(bool isDark) => isDark ? 0.45 : 0.52;
  static const double opacityContent = 0.94;
  static const double opacityHighContrast = 0.96;

  // Border / shadow / specular alpha.
  static double borderAlpha(bool isDark) => isDark ? 0.28 : 0.35;
  static double shadowAlpha(bool isDark) => isDark ? 0.35 : 0.14;
  static double specularAlpha(bool isDark) => isDark ? 0.10 : 0.28;

  // Default radii (geometry may still be overridden per surface).
  static const double radiusBar = 18;
  static const double radiusFloating = 22;

  // Shader params (logical/UV; converted to physical px in the shader path).
  static const double refractiveIndex = 1.6;
  static const double rimWidth = 42; // thick bevel -> pronounced lensing
  static const double aberration = 0.05; // prismatic rim fringe
  static const double blurCoeff = 0.03; // ~4 physical px of frost at the rim

  // Liquid-glass rim effects (0..1 strengths; tuned on-device).
  static const double fresnel = 0.8;
  static const double glare = 0.6;

  /// Strength of the physically-based (Snell) refraction march. The dominant
  /// "how much does the glass bend the background" dial.
  static const double refractIntensity = 0.85;

  /// Base tint colour: white (light) / charcoal (dark).
  static Color tint(bool isDark) =>
      isDark ? MqColors.charcoal800 : const Color(0xFFFFFFFF);
}
