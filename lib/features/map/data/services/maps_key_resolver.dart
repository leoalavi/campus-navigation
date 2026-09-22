import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/core/config/env_config.dart';

/// Whether this build can actually render Google Maps.
enum MapsKeyStatus {
  /// A key is available — from the Dart define or from the platform's own
  /// configuration (Android manifest / iOS Info.plist).
  configured,

  /// Native platform, but no key anywhere. Google Maps would render grey.
  missing,

  /// `google_maps_flutter` has no implementation for this platform at all
  /// (macOS, Linux, Windows). Not a configuration problem — nothing to fix.
  unsupportedPlatform,
}

/// Resolves the Google Maps key at **runtime**, not compile time.
///
/// `EnvConfig.googleMapsApiKey` is a `--dart-define`, so a build launched by a
/// plain `flutter run` (or from Xcode/Android Studio) reported "no key" even
/// when the native side was perfectly well keyed by Gradle/Info.plist — and the
/// map silently fell back to OpenStreetMap while the toggle still said "Google
/// Maps". Asking the platform for the key it was actually built with is what
/// makes the gate agree with reality.
///
/// Mirrors the runtime key-resolution approach used in the sibling astronomy
/// project, which hit and documented this same compile-time-define trap.
class MapsKeyResolver {
  MapsKeyResolver({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'campus_navigation/maps_config';

  final MethodChannel _channel;

  MapsKeyStatus? _cached;

  static bool get _isNativeMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<MapsKeyStatus> resolve() async {
    final cached = _cached;
    if (cached != null) return cached;
    return _cached = await _resolveUncached();
  }

  Future<MapsKeyStatus> _resolveUncached() async {
    // Desktop has no Google Maps implementation to key.
    if (!kIsWeb && !_isNativeMobile) return MapsKeyStatus.unsupportedPlatform;

    // A compile-time define wins: it is the explicit, per-build answer.
    if (EnvConfig.hasGoogleMapsApiKey) return MapsKeyStatus.configured;

    // Web has no method channel; its key is injected into the page instead,
    // and that check lives with the web renderer.
    if (kIsWeb) return MapsKeyStatus.missing;

    try {
      final key = await _channel.invokeMethod<String>('resolveMapsApiKey');
      return (key != null && key.trim().isNotEmpty)
          ? MapsKeyStatus.configured
          : MapsKeyStatus.missing;
    } on MissingPluginException {
      // The channel isn't registered on this platform (currently iOS, which
      // keys the SDK natively in AppDelegate from Info.plist `GMSApiKey`).
      // Falling back to OSM here would reintroduce the exact "Google Maps tab
      // shows OpenStreetMap" bug on a correctly-keyed build, so defer to the
      // native SDK — it surfaces its own authorization error if the key is
      // absent.
      return MapsKeyStatus.configured;
    } on PlatformException {
      return MapsKeyStatus.missing;
    }
  }
}

final mapsKeyResolverProvider = Provider<MapsKeyResolver>(
  (ref) => MapsKeyResolver(),
);

final mapsKeyStatusProvider = FutureProvider<MapsKeyStatus>(
  (ref) => ref.watch(mapsKeyResolverProvider).resolve(),
);
