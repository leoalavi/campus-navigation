import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_navigation/features/scan/data/repositories/trail_repository.dart';
import 'package:campus_navigation/features/indoor/data/repositories/indoor_repository.dart';
import 'package:campus_navigation/features/scan/data/repositories/buildings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled open_day_trail.json seeds 9 locations / 16 stops', () async {
    final manifest = await TrailRepository().load();
    expect(manifest.locations.length, 9);
    final stopCount = manifest.locations.fold<int>(
      0,
      (n, l) => n + l.stops.length,
    );
    expect(stopCount, 16);
    final wallys1 = manifest.byId('wallys-1')!;
    expect(wallys1.buildingId, 'wallys-1');
    expect(
      wallys1.stops.map((s) => s.arSceneId),
      containsAll(['theatre-g03', 'theatre-102', 'theatre-202']),
    );
  });

  test(
    'every location has a real bundled photo and a description (cards not empty)',
    () async {
      final manifest = await TrailRepository().load();
      for (final loc in manifest.locations) {
        // Description present and reasonably sized (the curated 2-3 sentences).
        expect(
          loc.description,
          isNotNull,
          reason: 'no description for ${loc.locationId}',
        );
        expect(loc.description!.trim().length, greaterThan(40));
        // Photo is set, not the placeholder, and actually bundles.
        expect(
          loc.photos,
          isNotEmpty,
          reason: 'no photo for ${loc.locationId}',
        );
        final photo = loc.photos.first;
        expect(
          photo.contains('_placeholder'),
          isFalse,
          reason: '${loc.locationId} still on placeholder photo',
        );
        // rootBundle.load throws if the asset is missing from the bundle.
        await expectLater(rootBundle.load(photo), completes);
      }
    },
  );

  test(
    'every location bridges to a campus-map building with real coordinates',
    () async {
      // Regression: the trail buildingId slugs ("wallys-29") resolve only to
      // coordinate-less Open Day stubs in buildings.json, so "View on Campus
      // Map" used to land on the overlay (0,0) corner. Each location must now
      // carry a mapBuildingCode pointing at a real, placed building.
      final manifest = await TrailRepository().load();
      final registry = await BuildingsRepository().load();
      for (final loc in manifest.locations) {
        final code = loc.mapBuildingCode;
        expect(
          code,
          isNotNull,
          reason: 'no mapBuildingCode for ${loc.locationId}',
        );
        final building = registry.byCode(code!);
        expect(
          building,
          isNotNull,
          reason: '$code (for ${loc.locationId}) missing from buildings.json',
        );
        final hasRealCoords = building!.campusX != 0 || building.campusY != 0;
        expect(
          hasRealCoords,
          isTrue,
          reason: '$code has no campus coordinates (would focus 0,0)',
        );
      }
    },
  );

  test('every location has a loadable 360° tour with an entrance node', () async {
    // Tours are keyed by the campus building id (mapBuildingCode, e.g.
    // `23WW`) — the same id the map and building sheet use — not by the
    // Open Day slug, which only identifies stamps and visits.
    final manifest = await TrailRepository().load();
    final repo = IndoorRepository();
    for (final loc in manifest.locations) {
      final code = loc.mapBuildingCode!;
      final indoor = await repo.load(code);
      expect(indoor, isNotNull, reason: 'missing manifest for $code');
      expect(indoor!.nodes.any((n) => n.id == loc.arSceneId), isTrue);
      // Each stop's arSceneId must exist as a node.
      for (final stop in loc.stops) {
        expect(
          indoor.nodes.any((n) => n.id == stop.arSceneId),
          isTrue,
          reason: 'no node ${stop.arSceneId} in $code',
        );
      }
      // Neighbour parsing guard: the `targetId`/`heading` keys must populate
      // NodeNeighbour (not null/default) — otherwise AR hotspots break silently.
      final entrance = indoor.nodes.firstWhere((n) => n.id == 'entrance');
      expect(
        entrance.neighbours,
        isNotEmpty,
        reason: 'entrance has no parsed neighbours in $code',
      );
      expect(entrance.neighbours.first.id, isNotEmpty);
    }
  });

  test('byMapBuildingCode maps a campus building back to its Open Day '
      'location', () async {
    final manifest = await TrailRepository().load();
    for (final loc in manifest.locations) {
      expect(
        manifest.byMapBuildingCode(loc.mapBuildingCode!)?.locationId,
        loc.locationId,
      );
    }
  });
}
