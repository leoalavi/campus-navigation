import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_navigation/core/config/env_config.dart';

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

    // Web has no method channel; its key is injected into the page instead,
    // and that check lives with the web renderer. A compile-time define is
    // the only signal available there.
    if (kIsWeb) {
      return EnvConfig.hasGoogleMapsApiKey
          ? MapsKeyStatus.configured
          : MapsKeyStatus.missing;
    }

    // On Android and iOS the native SDK is what needs the key, and a
    // --dart-define never reaches it. So the platform's answer is the only
    // one that matters: trusting the define here let an iOS build with no
    // Info.plist `GMSApiKey` create a map view and crash with
    // GMSServicesException.
    try {
      final key = await _channel.invokeMethod<String>('resolveMapsApiKey');
      return (key != null && key.trim().isNotEmpty)
          ? MapsKeyStatus.configured
          : MapsKeyStatus.missing;
    } on MissingPluginException {
      // Both MainActivity and AppDelegate register the channel, so this means
      // a native build that predates it. Without proof of a key, a map view
      // can crash the app (iOS) or render grey (Android) — fall back to OSM.
      return MapsKeyStatus.missing;
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
