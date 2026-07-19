import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads and caches the Liquid Glass-inspired refraction shader program.
/// Impeller-only; callers fall back to frost when [ready] is false.
abstract final class GlassShaderCache {
  static ui.FragmentProgram? _program;
  static Future<void>? _loading;

  /// Idempotent + concurrency-safe: all callers await the same load future.
  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return; // no shader path here
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'shaders/glass_refraction.frag',
      );
    } catch (error, stack) {
      _program = null;
      debugPrint('GlassShaderCache: shader load failed: $error\n$stack');
    }
  }

  /// True when a shader-backed glass surface can be built.
  static bool get ready =>
      _program != null && ui.ImageFilter.isShaderFilterSupported;

  /// A fresh FragmentShader the CALLER owns and must `dispose()`.
  static ui.FragmentShader newShader() => _program!.fragmentShader();
}
