import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// The hand-held resting pose (phone pitched back ~27° from vertical) treated
/// as tilt-neutral, so the glare starts at its designed spot and moves both
/// ways as you pitch the phone toward flat or upright.
const double _restPitch = 0.45;

/// Maps one raw accelerometer reading (m/s², gravity included) to the glare
/// tilt target, each axis roughly in [-1, 1].
///
/// Uses the *normalized gravity direction*, not raw axes / 9.81: the raw y
/// axis reads ~±9.81 for every upright holding pose (gravity runs along the
/// phone's length), which pinned the clamped tilt at 1.0 and froze the glare.
/// `x/|g|` is roll (lean the phone left/right) and `z/|g|` is pitch from
/// vertical (0 upright → 1 flat screen-up) — both actually vary as you tilt.
Offset glassTiltTarget(double x, double y, double z) {
  final norm = math.sqrt(x * x + y * y + z * z);
  if (norm < 1e-3) return Offset.zero; // free-fall/garbage sample: ignore
  final tx = (x / norm).clamp(-1.0, 1.0);
  final ty = (z / norm - _restPitch).clamp(-1.0, 1.0);
  return Offset(tx, ty);
}

/// A globally-shared, smoothed device tilt (relative to gravity) that the glass
/// shader reads so highlights track how you hold the phone — like light moving
/// on real glass. Zero when unavailable (simulator/desktop), so the glass
/// simply falls back to the time-based sway.
abstract final class GlassTilt {
  static final ValueNotifier<Offset> value = ValueNotifier<Offset>(Offset.zero);

  // Intentionally app-lifetime (a global singleton); never cancelled.
  // ignore: cancel_subscriptions
  static StreamSubscription<AccelerometerEvent>? _sub;
  static double _x = 0, _y = 0;

  static void start() {
    if (_sub != null) return;
    try {
      _sub =
          accelerometerEventStream(
            // ~50 Hz: at the default 5 Hz the low-pass filter needed >1 s to
            // react, which read as "the glare is stuck".
            samplingPeriod: SensorInterval.gameInterval,
          ).listen(
            (e) {
              final target = glassTiltTarget(e.x, e.y, e.z);
              // Low-pass smooth to kill jitter (~0.15 s time constant @50 Hz).
              _x += (target.dx - _x) * 0.12;
              _y += (target.dy - _y) * 0.12;
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
