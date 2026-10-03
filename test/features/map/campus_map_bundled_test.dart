import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The illustrated campus map works offline because it ships in the bundle.
///
/// (The separate "Offline Campus Maps" download in Settings caches street
/// tiles for the Google renderer's fallback view — see
/// `desktop_map_fallback_view.dart` — and is not what these tests cover.)
void main() {
  test('the campus map and its overlays ship with the app', () {
    for (final asset in const [
      'assets/maps/mq-campus.png',
      'assets/maps/overlay_parking.png',
      'assets/maps/overlay_water.png',
      'assets/maps/overlay_accessibility.png',
      'assets/maps/overlay_permits.png',
    ]) {
      expect(
        File(asset).existsSync(),
        isTrue,
        reason: '$asset is what makes the map work offline',
      );
    }
  });

  test('the campus map is drawn from the bundle, not from network tiles', () {
    final overlay = File(
      'lib/features/map/presentation/widgets/campus/campus_map_overlay.dart',
    ).readAsStringSync();
    expect(overlay, contains('AssetImage'));
    expect(
      overlay.contains('urlTemplate'),
      isFalse,
      reason: 'a tile URL here would mean the map needs the network',
    );
  });
}
