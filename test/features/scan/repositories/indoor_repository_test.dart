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
    test('loads and parses bundled C3A.json with targetId/heading', () async {
      final manifest = await IndoorRepository().load('C3A');
      expect(manifest, isNotNull);
      expect(manifest!.isEmpty, isFalse);
      final entrance = manifest.nodes.firstWhere((n) => n.id == 'entrance');
      expect(entrance.neighbours, isNotEmpty);
      expect(entrance.neighbours.first.id, 'ground_floor');
      expect(entrance.neighbours.first.bearing, 0);
    });

    test('loads and parses bundled 18WW.json', () async {
      final manifest = await IndoorRepository().load('18WW');
      expect(manifest, isNotNull);
      expect(manifest!.nodes, isNotEmpty);
      final lobby = manifest.nodes.firstWhere((n) => n.id == 'lobby');
      expect(lobby.neighbours.first.id, 'service_desk');
    });
  });
}
