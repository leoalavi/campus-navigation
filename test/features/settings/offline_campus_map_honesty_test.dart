import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "Offline Campus Map" must describe reality.
///
/// The campus map is a bundled asset, and the building registry, Open Day
/// data and indoor tours are bundled JSON/images — all already usable with no
/// connection. The setting used to offer an OpenStreetMap tile download whose
/// store *nothing in the app read* (`OfflineMapsService.tileProvider()` had no
/// callers), then reported "Downloaded" for a capability the user already had.
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

  test('settings no longer offers a download for already-bundled content', () {
    final page = File(
      'lib/features/settings/presentation/pages/settings_page.dart',
    ).readAsStringSync();
    expect(
      page.contains('downloadCampusTiles'),
      isFalse,
      reason:
          'the tile download fed a store no screen reads — offering it spent '
          'the user data and then claimed a capability they already had',
    );
    expect(
      page.contains('offlineCampusMapsBundled'),
      isTrue,
      reason: 'the row should state the honest offline status instead',
    );
  });

  test('the offline copy names what still needs a connection', () {
    final arb = File('lib/app/l10n/app_en.arb').readAsStringSync();
    final detail = RegExp(
      r'"offlineCampusMapsBundledDetail":\s*"([^"]+)"',
    ).firstMatch(arb)!.group(1)!;
    // Claiming blanket offline support would be the dishonest failure mode.
    for (final online in const ['metro', 'route']) {
      expect(
        detail.toLowerCase(),
        contains(online),
        reason: 'users must be told $online still needs a connection',
      );
    }
  });
}
