import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/features/map/data/services/maps_key_resolver.dart';

/// The Google Maps tab rendered OpenStreetMap on correctly-keyed builds
/// because the gate only consulted a compile-time `--dart-define`. These lock
/// in that the platform's own key is consulted at runtime instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('campus_navigation/maps_config');

  void stubChannel(String? key, {Object? throwError}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (throwError != null) throw throwError;
          if (call.method == 'resolveMapsApiKey') return key;
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('a key from the platform manifest counts as configured', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    stubChannel('AIza-native-key-from-manifest');

    expect(await MapsKeyResolver().resolve(), MapsKeyStatus.configured);
  });

  test('an empty platform key is reported missing, not configured', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    stubChannel('');

    expect(await MapsKeyResolver().resolve(), MapsKeyStatus.missing);
  });

  test('whitespace is not mistaken for a key', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    stubChannel('   ');

    expect(await MapsKeyResolver().resolve(), MapsKeyStatus.missing);
  });

  // iOS keys its SDK natively in AppDelegate from Info.plist and registers no
  // channel. Falling back to OSM there would be the original bug again.
  test('a missing channel defers to the native SDK rather than OSM', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    stubChannel(null, throwError: MissingPluginException('no channel'));

    expect(await MapsKeyResolver().resolve(), MapsKeyStatus.configured);
  });

  test('a platform error degrades to the OSM renderer', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    stubChannel(null, throwError: PlatformException(code: 'boom'));

    expect(await MapsKeyResolver().resolve(), MapsKeyStatus.missing);
  });

  test('desktop reports unsupported, not misconfigured', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    stubChannel('AIza-should-not-be-consulted');

    expect(
      await MapsKeyResolver().resolve(),
      MapsKeyStatus.unsupportedPlatform,
    );
  });

  test('the resolved status is cached', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls++;
          return 'AIza-key';
        });

    final resolver = MapsKeyResolver();
    await resolver.resolve();
    await resolver.resolve();

    expect(calls, 1);
  });
}
