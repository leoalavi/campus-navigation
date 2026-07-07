import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/data/repositories/indoor_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IndoorRepository', () {
    test('returns null for missing building', () async {
      final repo = IndoorRepository();
      final manifest = await repo.load('nonexistent');
      expect(manifest, isNull);
    });

    // Regression guard: the real manifest assets must be bundled (they live in
    // the non-recursive `assets/data/indoor/` subdir) AND parse with the
    // `targetId`/`heading` neighbour schema. Building codes are case-sensitive.
    test(
      'loads and parses bundled wallys-1.json with targetId/heading',
      () async {
        final manifest = await IndoorRepository().load('wallys-1');
        expect(manifest, isNotNull);
        expect(manifest!.isEmpty, isFalse);
        final entrance = manifest.nodes.firstWhere((n) => n.id == 'entrance');
        expect(entrance.neighbours, isNotEmpty);
        expect(entrance.neighbours.first.id, 'theatre-g03');
        expect(entrance.neighbours.first.bearing, -10);
      },
    );

    test('loads and parses bundled hadenfeld-10.json', () async {
      final manifest = await IndoorRepository().load('hadenfeld-10');
      expect(manifest, isNotNull);
      expect(manifest!.nodes, isNotEmpty);
      final entrance = manifest.nodes.firstWhere((n) => n.id == 'entrance');
      expect(entrance.neighbours.first.id, 'theatre-1');
    });

    // The legacy C3A/18WW demo manifests referenced panorama images that were
    // never supplied — a viewer opened against them rendered black. They were
    // removed; a load for those codes must now cleanly report "no preview"
    // (null) instead of handing the webview a broken manifest.
    test('returns null for the removed legacy demo manifests', () async {
      final repo = IndoorRepository();
      expect(await repo.load('C3A'), isNull);
      expect(await repo.load('18WW'), isNull);
    });
  });
}
