import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/features/indoor/data/repositories/indoor_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IndoorRepository', () {
    test('reports no tour for an unknown building', () async {
      final repo = IndoorRepository();
      expect(await repo.hasTour('nonexistent'), isFalse);
      expect(await repo.sceneCount('nonexistent'), isNull);
      expect(await repo.load('nonexistent'), isNull);
    });

    // Migration guard: tours are keyed by the canonical building id, never by
    // the Open Day event slugs the source repos used. A regression here would
    // silently reintroduce two identities for one place.
    test('tours are keyed by canonical building id, not event slugs', () async {
      final ids = await IndoorRepository().tourIds();
      expect(ids, contains('17WW'));
      expect(ids, contains('14SCO'));
      expect(ids, contains('MQTH'));
      for (final slug in const [
        'wallys-17',
        'wallys-21',
        'wallys-23',
        'ondaatje-14',
        'hadenfeld-10',
        '1-central-courtyard',
        '17-wallys-walk',
        'gymnasium-road',
      ]) {
        expect(ids, isNot(contains(slug)), reason: '$slug must not ship');
      }
    });

    test('loads a tour that kept its authored hotspot graph', () async {
      // 10HA came from MQ Journey, which authored neighbour headings.
      final manifest = await IndoorRepository().load('10HA');
      expect(manifest, isNotNull);
      final entrance = manifest!.nodes.firstWhere((n) => n.id == 'entrance');
      expect(entrance.neighbours, isNotEmpty);
      expect(entrance.neighbours.first.bearing, isA<double>());
    });

    test('loads a tour imported from the newer imagery set', () async {
      // 17WW came from Astronomy Open Night: wider coverage, no hotspot graph.
      final manifest = await IndoorRepository().load('17WW');
      expect(manifest, isNotNull);
      expect(manifest!.nodes.map((n) => n.id), contains('lobby'));
      expect(manifest.nodes.length, 4);
    });

    test('scene counts match the loaded manifests', () async {
      final repo = IndoorRepository();
      for (final id in await repo.tourIds()) {
        final manifest = await repo.load(id);
        expect(manifest, isNotNull, reason: '$id listed but not loadable');
        expect(
          await repo.sceneCount(id),
          manifest!.nodes.length,
          reason: '$id index count disagrees with its manifest',
        );
      }
    });
  });
}
