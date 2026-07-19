import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_glass.dart';

/// Variants of the Liquid Glass-inspired ("Glass UI layer") material.
enum GlassVariant { bar, control, content }

/// Which rung of the accessibility fallback ladder to render.
enum GlassRenderMode { shader, frost, solid }

/// Pure policy: which rung to render. Unit-tested across all combinations.
GlassRenderMode resolveGlassRenderMode({
  required GlassVariant variant,
  required bool highContrast,
  required bool disableAnimations,
  required bool shaderSupported,
}) {
  if (variant == GlassVariant.content || highContrast) {
    return GlassRenderMode.solid;
  }
  if (disableAnimations || !shaderSupported) {
    return GlassRenderMode.frost;
  }
  return GlassRenderMode.shader;
}

/// A single tokenized glass surface. See
/// docs/superpowers/specs/2026-07-19-liquid-glass-ui-design.md.
///
/// `control`/`bar` render a frosted [BackdropFilter] (upgraded to a refraction
/// shader where Impeller supports it — see glass_shader.dart); `content` is a
/// near-opaque box so text legibility never depends on the backdrop.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.variant = GlassVariant.control,
    this.borderRadius,
    this.padding,
    this.color,
    this.borderColor,
    this.borderWidth,
    this.constraints,
    this.boxShadow,
  });

  final Widget child;
  final GlassVariant variant;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Base surface tint override (applied in every rung).
  final Color? color;

  /// Border colour override (forced opaque under high contrast).
  final Color? borderColor;

  /// Border width override (panels use 0.6).
  final double? borderWidth;
  final BoxConstraints? constraints;
  final List<BoxShadow>? boxShadow;

  // Task 3 flips this to GlassShaderCache.ready.
  bool _shaderSupported(BuildContext context) => false;

  BorderRadius get _defaultRadius => switch (variant) {
    GlassVariant.bar => BorderRadius.circular(MqGlass.radiusBar),
    GlassVariant.control ||
    GlassVariant.content => BorderRadius.circular(MqGlass.radiusFloating),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final radius = borderRadius ?? _defaultRadius;

    final mode = resolveGlassRenderMode(
      variant: variant,
      highContrast: highContrast,
      disableAnimations: disableAnimations,
      shaderSupported: _shaderSupported(context),
    );

    switch (mode) {
      case GlassRenderMode.solid:
        return _solid(isDark, radius, highContrast: highContrast);
      case GlassRenderMode.frost:
      case GlassRenderMode.shader:
        return _frost(context, isDark, radius, useShader: false);
    }
  }

  Widget _padded(Widget c) =>
      padding == null ? c : Padding(padding: padding!, child: c);

  Color _resolveBorderColor(bool isDark, bool highContrast) {
    if (borderColor != null) {
      // Force opaque under high contrast so custom translucent borders stay visible.
      return highContrast ? borderColor!.withValues(alpha: 1.0) : borderColor!;
    }
    final alpha = highContrast ? 1.0 : MqGlass.borderAlpha(isDark);
    return (isDark ? Colors.white : MqColors.charcoal800).withValues(
      alpha: alpha,
    );
  }

  BoxBorder _border(bool isDark, bool highContrast) {
    final side = BorderSide(
      color: _resolveBorderColor(isDark, highContrast),
      width: borderWidth ?? 1.0,
    );
    return variant == GlassVariant.bar
        ? Border(top: side)
        : Border.fromBorderSide(side);
  }

  List<BoxShadow> _shadow(bool isDark) {
    if (boxShadow != null) return boxShadow!;
    if (variant == GlassVariant.bar) return const [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: MqGlass.shadowAlpha(isDark)),
        blurRadius: 32,
        offset: const Offset(0, 12),
      ),
    ];
  }

  BoxDecoration _specular(bool isDark, BorderRadius radius) => BoxDecoration(
    borderRadius: radius,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: MqGlass.specularAlpha(isDark)),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5],
    ),
  );

  Widget _solid(
    bool isDark,
    BorderRadius radius, {
    required bool highContrast,
  }) {
    final opacity = highContrast
        ? MqGlass.opacityHighContrast
        : MqGlass.opacityContent;
    final fill = (color ?? MqGlass.tint(isDark)).withValues(alpha: opacity);
    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: _border(isDark, highContrast),
        boxShadow: highContrast ? const [] : _shadow(isDark),
      ),
      child: ClipRRect(borderRadius: radius, child: _padded(child)),
    );
    if (constraints != null) {
      box = ConstrainedBox(constraints: constraints!, child: box);
    }
    return box;
  }

  Widget _frost(
    BuildContext context,
    bool isDark,
    BorderRadius radius, {
    required bool useShader,
  }) {
    final inner = Container(
      decoration: BoxDecoration(
        color: (color ?? MqGlass.tint(isDark)).withValues(
          alpha: MqGlass.opacityRegular(isDark),
        ),
        borderRadius: radius,
        border: _border(isDark, false),
      ),
      foregroundDecoration: _specular(isDark, radius),
      child: _padded(child),
    );
    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: _shadow(isDark),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: MqGlass.blurMd,
            sigmaY: MqGlass.blurMd,
          ),
          child: inner,
        ),
      ),
    );
    if (constraints != null) {
      box = ConstrainedBox(constraints: constraints!, child: box);
    }
    return box;
  }
}
