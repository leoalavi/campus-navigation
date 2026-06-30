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

    test('defaults photos/stops to empty and arSceneId to null when absent', () {
      const raw = '{"locations":[{"locationId":"x","title":"X"}]}';
      final loc = TrailManifest.fromJson(raw).byId('x')!;
      expect(loc.photos, isEmpty);
      expect(loc.stops, isEmpty);
      expect(loc.arSceneId, isNull);
    });
  });
}
