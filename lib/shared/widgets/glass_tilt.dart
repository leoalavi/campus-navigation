import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A globally-shared, smoothed device tilt (relative to gravity) that the glass
/// shader reads so highlights track how you hold the phone — like light moving
/// on real glass. Each axis is roughly in [-1, 1]. Zero when unavailable
/// (simulator/desktop), so the glass simply falls back to the time-based sway.
abstract final class GlassTilt {
  static final ValueNotifier<Offset> value = ValueNotifier<Offset>(Offset.zero);

  // Intentionally app-lifetime (a global singleton); never cancelled.
  // ignore: cancel_subscriptions
  static StreamSubscription<AccelerometerEvent>? _sub;
  static double _x = 0, _y = 0;

  static void start() {
    if (_sub != null) return;
    try {
      _sub = accelerometerEventStream().listen(
        (e) {
          // Gravity ~9.81 m/s^2. x ≈ left/right tilt, y ≈ forward/back tilt.
          final tx = (e.x / 9.81).clamp(-1.0, 1.0);
          final ty = (e.y / 9.81).clamp(-1.0, 1.0);
          // Low-pass smooth to kill jitter.
          _x += (tx - _x) * 0.15;
          _y += (ty - _y) * 0.15;
          value.value = Offset(_x, _y);
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      // Sensor not available — leave tilt at zero.
    }
  }
}
