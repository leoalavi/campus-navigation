import 'package:flutter_test/flutter_test.dart';
import 'package:campus_navigation/features/map/domain/entities/route_leg.dart';

void main() {
  group('MapRoute', () {
    test('parses Google Directions API response into route instructions', () {
      final route = MapRoute.fromJson({
        'status': 'OK',
        'routes': [
          {
            'overview_polyline': {'points': 'abc123'},
            'legs': [
              {
                'distance': {'value': 1450, 'text': '1.5 km'},
                'duration': {'value': 480, 'text': '8 mins'},
                'steps': [
                  {
                    'distance': {'value': 100, 'text': '100 m'},
                    'html_instructions': 'Head <b>north</b>',
                  },
                  {
                    'distance': {'value': 20, 'text': '20 m'},
                    'html_instructions': 'Turn <b>right</b>',
                  },
                ],
              },
            ],
          },
        ],
      }, TravelMode.walk);

      expect(route.travelMode, TravelMode.walk);
      expect(route.distanceMeters, 1450);
      expect(route.durationSeconds, 480);
      expect(route.encodedPolyline, 'abc123');
      expect(route.instructions, hasLength(2));
      expect(route.instructions.first.text, 'Head north');
    });

    test('parses normalized maps-routes response', () {
      final route = MapRoute.fromJson({
        'renderer': 'google',
        'mode': 'WALK',
        'distanceMeters': 540,
        'durationSeconds': 420,
        'encodedPolyline': 'abc123',
        'points': [
          {'lat': -33.774, 'lng': 151.111},
          {'lat': -33.775, 'lng': 151.112},
        ],
        'steps': [
          {
            'instruction': 'Head north',
            'distanceMeters': 100,
            'durationSeconds': 60,
          },
          {
            'instruction': 'Turn right',
            'distanceMeters': 50,
            'durationSeconds': 30,
          },
        ],
      }, TravelMode.walk);

      expect(route.distanceMeters, 540);
      expect(route.durationSeconds, 420);
      expect(route.encodedPolyline, 'abc123');
      expect(route.points, hasLength(2));
      expect(route.instructions, hasLength(2));
      expect(route.instructions.last.text, 'Turn right');
    });

    test('parses Routes API duration strings from normalized responses', () {
      final route = MapRoute.fromJson({
        'renderer': 'google',
        'mode': 'WALK',
        'distanceMeters': 540,
        'duration': '420s',
        'encodedPolyline': 'abc123',
        'points': const [
          {'lat': -33.774, 'lng': 151.111},
        ],
        'steps': const [
          {
            'instruction': 'Head north',
            'distanceMeters': 100,
            'durationSeconds': 60,
          },
        ],
      }, TravelMode.walk);

      expect(route.durationSeconds, 420);
    });

    test('throws a helpful error when legacy Directions status is not OK', () {
      expect(
        () => MapRoute.fromJson({
          'status': 'ZERO_RESULTS',
          'routes': const [],
        }, TravelMode.walk),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('ZERO_RESULTS'),
          ),
        ),
      );
    });

    // A transit request TfNSW answers with a footpath-only journey used to be
    // shown as a transit trip with transit turn-by-turn.
    test('flags a walking route served for a transit request', () {
      final route = MapRoute.fromJson({
        'mode': 'WALK',
        'distanceMeters': 313,
        'durationSeconds': 281,
        'points': const <Map<String, double>>[],
        'steps': const <Map<String, Object>>[],
      }, TravelMode.transit);

      expect(route.travelMode, TravelMode.transit);
      expect(route.servedTravelMode, TravelMode.walk);
      expect(route.isWalkingFallback, isTrue);
    });

    test('a route served in the requested mode is not a fallback', () {
      final route = MapRoute.fromJson({
        'mode': 'TRANSIT',
        'distanceMeters': 4200,
        'durationSeconds': 900,
        'points': const <Map<String, double>>[],
        'steps': const <Map<String, Object>>[],
      }, TravelMode.transit);

      expect(route.servedTravelMode, TravelMode.transit);
      expect(route.isWalkingFallback, isFalse);
    });

    test('a response without a mode keeps the requested mode', () {
      final route = MapRoute.fromJson({
        'distanceMeters': 250,
        'durationSeconds': 180,
        'points': const <Map<String, double>>[],
      }, TravelMode.drive);

      expect(route.servedTravelMode, TravelMode.drive);
      expect(route.isWalkingFallback, isFalse);
    });
  });
}
