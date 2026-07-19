import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_glass.dart';
import 'package:mq_journey/shared/widgets/glass_shader.dart';

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

  bool _shaderSupported(BuildContext context) => GlassShaderCache.ready;

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
        return _frost(context, isDark, radius, useShader: false);
      case GlassRenderMode.shader:
        return _frost(context, isDark, radius, useShader: true);
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
    final baseTint = color ?? MqGlass.tint(isDark);
    final border = _border(isDark, false);
    final specular = _specular(isDark, radius);
    final inner = _padded(child);

    final Widget filtered;
    if (useShader) {
      filtered = _GlassShaderBackdrop(
        tint: baseTint,
        alpha: MqGlass.opacityRegular(isDark),
        radius: radius,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        border: border,
        specular: specular,
        child: inner,
      );
    } else {
      filtered = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: MqGlass.blurMd,
          sigmaY: MqGlass.blurMd,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: baseTint.withValues(alpha: MqGlass.opacityRegular(isDark)),
            borderRadius: radius,
            border: border,
          ),
          foregroundDecoration: specular,
          child: inner,
        ),
      );
    }

    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: _shadow(isDark),
      ),
      child: ClipRRect(borderRadius: radius, child: filtered),
    );
    if (constraints != null) {
      box = ConstrainedBox(constraints: constraints!, child: box);
    }
    return box;
  }
}

/// Owns one reusable [ui.FragmentShader] for a single glass surface.
/// Uniforms are set per build; the shader is disposed with the widget.
class _GlassShaderBackdrop extends StatefulWidget {
  const _GlassShaderBackdrop({
    required this.tint,
    required this.alpha,
    required this.radius,
    required this.devicePixelRatio,
    required this.border,
    required this.specular,
    required this.child,
  });

  final Color tint;
  final double alpha;
  final BorderRadius radius;
  final double devicePixelRatio;
  final BoxBorder border;
  final BoxDecoration specular;
  final Widget child;

  @override
  State<_GlassShaderBackdrop> createState() => _GlassShaderBackdropState();
}

class _GlassShaderBackdropState extends State<_GlassShaderBackdrop>
    with SingleTickerProviderStateMixin {
  late final ui.FragmentShader _shader = GlassShaderCache.newShader();
  late final Ticker _ticker;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    // Drives the living highlights (light sweep / sway / iridescence). Repaints
    // the glass each frame; that's the cost of the "alive" look.
    _ticker = createTicker((elapsed) {
      setState(() => _time = elapsed.inMicroseconds / 1e6);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = widget.devicePixelRatio;
    // Float indices 0/1 (uSize) + the sampler are engine-owned — never set them.
    _shader.setFloat(2, widget.radius.topLeft.x * dpr); // uRadius
    _shader.setFloat(3, MqGlass.rimWidth * dpr); // uRimPx
    _shader.setFloat(4, MqGlass.refractiveIndex); // uIor
    _shader.setFloat(
      5,
      MqGlass.aberration * MqGlass.rimWidth * dpr,
    ); // uAberrationPx
    _shader.setFloat(6, MqGlass.blurCoeff * MqGlass.rimWidth * dpr); // uBlurPx
    final r = widget.tint.r * widget.alpha;
    final g = widget.tint.g * widget.alpha;
    final b = widget.tint.b * widget.alpha;
    _shader.setFloat(7, r); // uTint.r (premultiplied)
    _shader.setFloat(8, g);
    _shader.setFloat(9, b);
    _shader.setFloat(10, widget.alpha);
    _shader.setFloat(11, MqGlass.fresnel); // uFresnel
    _shader.setFloat(12, MqGlass.glare); // uGlare
    _shader.setFloat(13, MqGlass.refractIntensity); // uRefractIntensity
    _shader.setFloat(14, _time); // uTime

    return BackdropFilter(
      filter: ui.ImageFilter.shader(_shader),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent, // shader supplies the tint
          borderRadius: widget.radius,
          border: widget.border,
        ),
        foregroundDecoration: widget.specular,
        child: widget.child,
      ),
    );
  }
}
