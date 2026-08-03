import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/data/repositories/trail_repository.dart';
import 'package:mq_journey/features/scan/data/repositories/indoor_repository.dart';
import 'package:mq_journey/features/scan/data/repositories/buildings_repository.dart';

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

  test(
    'every building has a loadable indoor manifest with an entrance node',
    () async {
      final manifest = await TrailRepository().load();
      final repo = IndoorRepository();
      for (final loc in manifest.locations) {
        final indoor = await repo.load(loc.buildingId!);
        expect(
          indoor,
          isNotNull,
          reason: 'missing manifest for ${loc.buildingId}',
        );
        expect(indoor!.nodes.any((n) => n.id == 'entrance'), isTrue);
        // Each stop's arSceneId must exist as a node.
        for (final stop in loc.stops) {
          expect(
            indoor.nodes.any((n) => n.id == stop.arSceneId),
            isTrue,
            reason: 'no node ${stop.arSceneId} in ${loc.buildingId}',
          );
        }
        // Neighbour parsing guard: the `targetId`/`heading` keys must populate
        // NodeNeighbour (not null/default) — otherwise AR hotspots break silently.
        final entrance = indoor.nodes.firstWhere((n) => n.id == 'entrance');
        expect(
          entrance.neighbours,
          isNotEmpty,
          reason: 'entrance has no parsed neighbours in ${loc.buildingId}',
        );
        expect(entrance.neighbours.first.id, isNotEmpty);
      }
    },
  );

  test('byMapBuildingCode bridges a campus-map building code back to its '
      'indoor manifest (regression: AR mode entered via a map-selected '
      'building used to request "<mapBuildingCode>.json", which never '
      'exists — manifests are keyed by the trail buildingId slug)', () async {
    final manifest = await TrailRepository().load();
    final repo = IndoorRepository();
    for (final loc in manifest.locations) {
      final mapCode = loc.mapBuildingCode!;
      // The raw map code alone doesn't resolve to a manifest...
      expect(await repo.load(mapCode), isNull, reason: mapCode);
      // ...but bridging through the trail manifest does.
      final resolved = manifest.byMapBuildingCode(mapCode)?.buildingId;
      expect(resolved, loc.buildingId);
      expect(await repo.load(resolved!), isNotNull, reason: resolved);
    }
  });
}
