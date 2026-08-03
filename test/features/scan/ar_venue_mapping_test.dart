import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';

/// Every Open Day venue that the campus map can show must also resolve to an
/// AR manifest, by *stable code* — never by display title.
///
/// Price Theatre is the case that broke: `buildings.json` gives it its own
/// pin (code `PRICE`), but its panorama lives inside the 23 Wally's Walk
/// manifest as the `price` node. `mapBuildingCode` is 1:1, so `PRICE` matched
/// nothing and AR reported "no indoor preview" for a location the map had
/// just displayed. It now resolves through an explicit alias.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TrailManifest trail;
  late OpenDayData openDay;

  setUpAll(() async {
    trail = TrailManifest.fromJson(
      await rootBundle.loadString('assets/data/open_day_trail.json'),
    );
    openDay = OpenDayData.fromJson(
      jsonDecode(await rootBundle.loadString('assets/data/open_day.json'))
          as Map<String, dynamic>,
    );
  });

  test('PRICE resolves to the 23 Wally\'s Walk manifest, price scene', () {
    final loc = trail.byMapBuildingCode('PRICE');
    expect(loc, isNotNull, reason: 'Price Theatre must resolve to a manifest');
    expect(loc!.buildingId, 'wallys-23');
    expect(
      trail.arSceneForMapBuildingCode('PRICE'),
      'price',
      reason: 'an aliased pin should open on its own panorama',
    );
  });

  test(
    'a location\'s primary code opens on its own entrance, not an alias',
    () {
      expect(trail.byMapBuildingCode('23WW')?.buildingId, 'wallys-23');
      expect(
        trail.arSceneForMapBuildingCode('23WW'),
        isNull,
        reason: 'the primary code keeps the default entrance scene',
      );
    },
  );

  test('alias lookup is case-insensitive and code-based', () {
    expect(trail.byMapBuildingCode('price')?.buildingId, 'wallys-23');
    expect(trail.byMapBuildingCode('Price')?.buildingId, 'wallys-23');
  });

  test('no AR lookup succeeds via a display title', () {
    // Titles must never be identifiers — they are localised in the UI.
    for (final title in const [
      'Price Theatre',
      'Price Building',
      "23 Wally's Walk",
    ]) {
      expect(
        trail.byMapBuildingCode(title),
        isNull,
        reason: '"$title" is display text and must not resolve an AR venue',
      );
    }
  });

  test('every Open Day building code resolves to an AR manifest', () {
    final codes = <String>{
      for (final e in openDay.events)
        if (e.buildingCode != null && e.buildingCode!.isNotEmpty)
          e.buildingCode!.toUpperCase(),
    };
    expect(codes, isNotEmpty);

    final unresolved = <String>[];
    for (final code in codes) {
      if (trail.byMapBuildingCode(code) == null) unresolved.add(code);
    }
    expect(
      unresolved,
      isEmpty,
      reason:
          'these Open Day venues can be shown on the map but have no AR '
          'manifest, so switching to AR would dead-end: $unresolved',
    );
  });

  test('an unknown code resolves to nothing rather than a wrong venue', () {
    expect(trail.byMapBuildingCode('NOT-A-BUILDING'), isNull);
    expect(trail.arSceneForMapBuildingCode('NOT-A-BUILDING'), isNull);
  });

  test('every alias target names a real scene in its own manifest', () async {
    for (final loc in trail.locations) {
      for (final entry in loc.arAliases.entries) {
        final raw = await rootBundle.loadString(
          'assets/data/indoor/${loc.buildingId}.json',
        );
        final nodes =
            (jsonDecode(raw) as Map<String, dynamic>)['nodes'] as List;
        final ids = nodes.map((n) => (n as Map)['id'] as String).toSet();
        expect(
          ids,
          contains(entry.value),
          reason:
              'alias ${entry.key} points at scene "${entry.value}", which '
              '${loc.buildingId} does not have',
        );
      }
    }
  });
}
