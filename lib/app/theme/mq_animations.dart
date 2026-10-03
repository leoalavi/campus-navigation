import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/features/settings/presentation/controllers/settings_controller.dart';

/// Macquarie University animation timing tokens.
///
/// Provides consistent durations and curves across the app,
/// preventing magic-number animation values.
abstract final class MqAnimations {
  // ── Durations ────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration sheet = Duration(milliseconds: 350);

  // ── Curves ───────────────────────────────────────────────
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve sheetCurve = Curves.easeOutCubic;

  /// Returns the provided [duration] unless the user has enabled
  /// "Reduced Motion" in settings, in which case it returns [Duration.zero].
  static Duration adaptive(Duration duration, WidgetRef ref) {
    final reducedMotion =
        ref.watch(settingsControllerProvider).value?.reducedMotion ?? false;
    return reducedMotion ? Duration.zero : duration;
  }
}
