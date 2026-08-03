import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';

void main() {
  group('TrailManifest', () {
    const validJson =
        '{"locations":[{"locationId":"lib-01","buildingId":"C3A","title":"Library"}]}';
    final manifest = TrailManifest.fromJson(validJson);

    test('contains returns true for known location', () {
      expect(manifest.contains('lib-01'), isTrue);
    });

    test('contains returns false for unknown location', () {
      expect(manifest.contains('unknown-99'), isFalse);
    });

    test('byId returns matching location', () {
      final loc = manifest.byId('lib-01');
      expect(loc, isNotNull);
      expect(loc!.title, 'Library');
      expect(loc.buildingId, 'C3A');
    });

    test('byId returns null for missing', () {
      expect(manifest.byId('unknown'), isNull);
    });

    test('fromJson handles missing buildingId', () {
      final m = TrailManifest.fromJson(
        '{"locations":[{"locationId":"gen-01","title":"Generic"}]}',
      );
      expect(m.byId('gen-01')?.buildingId, isNull);
    });

    test('rejects malformed JSON gracefully', () {
      expect(() => TrailManifest.fromJson('not json'), throwsFormatException);
    });

    test('parses description and defaults it to null when absent', () {
      final withDesc = TrailManifest.fromJson(
        '{"locations":[{"locationId":"wallys-1","title":"1 Wally\'s Walk","description":"Three sentence blurb."}]}',
      );
      expect(withDesc.byId('wallys-1')?.description, 'Three sentence blurb.');
      expect(manifest.byId('lib-01')?.description, isNull);
    });

    test('parses mapBuildingCode and defaults it to null when absent', () {
      final withCode = TrailManifest.fromJson(
        '{"locations":[{"locationId":"wallys-29","buildingId":"wallys-29","mapBuildingCode":"29WW","title":"29 Wally\'s Walk"}]}',
      );
      expect(withCode.byId('wallys-29')?.mapBuildingCode, '29WW');
      // Absent key → null (the trail slug stays the only bridge, button gates off).
      expect(manifest.byId('lib-01')?.mapBuildingCode, isNull);
    });

    test(
      'byMapBuildingCode resolves the trail buildingId slug case-insensitively',
      () {
        final withCode = TrailManifest.fromJson(
          '{"locations":[{"locationId":"ondaatje-14","buildingId":"ondaatje-14","mapBuildingCode":"14SCO","title":"14 Sir Christopher Ondaatje Avenue"}]}',
        );
        final loc = withCode.byMapBuildingCode('14sco');
        expect(loc, isNotNull);
        expect(loc!.buildingId, 'ondaatje-14');
      },
    );

    test('byMapBuildingCode returns null when no location matches', () {
      expect(manifest.byMapBuildingCode('UNKNOWN'), isNull);
    });

    test('parses photos, arSceneId and stops', () {
      const raw = '''
      {"locations":[{
        "locationId":"wallys-1","buildingId":"wallys-1","title":"1 Wally's Walk",
        "photos":["assets/photos/_placeholder.jpg"],
        "arSceneId":"entrance",
        "stops":[
          {"stopId":"wallys-1-g03","title":"Theatre G03","arSceneId":"theatre-g03","scheduleLocationId":"wallys-1-g03"}
        ]
      }]}''';
      final m = TrailManifest.fromJson(raw);
      final loc = m.byId('wallys-1')!;
      expect(loc.photos, ['assets/photos/_placeholder.jpg']);
      expect(loc.arSceneId, 'entrance');
      expect(loc.stops.single.stopId, 'wallys-1-g03');
      expect(loc.stops.single.arSceneId, 'theatre-g03');
      expect(loc.stops.single.scheduleLocationId, 'wallys-1-g03');
    });

    test(
      'defaults photos/stops to empty and arSceneId to null when absent',
      () {
        const raw = '{"locations":[{"locationId":"x","title":"X"}]}';
        final loc = TrailManifest.fromJson(raw).byId('x')!;
        expect(loc.photos, isEmpty);
        expect(loc.stops, isEmpty);
        expect(loc.arSceneId, isNull);
      },
    );
  });
}
