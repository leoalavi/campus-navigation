import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:campus_navigation/features/map/data/datasources/maps_routes_remote_source.dart';
import 'package:campus_navigation/features/map/domain/entities/building.dart';
import 'package:campus_navigation/features/map/domain/entities/map_renderer_type.dart';
import 'package:campus_navigation/features/map/domain/entities/route_leg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late MockHttpClient mockHttpClient;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuthClient;
  late MapsRoutesRemoteSource remoteSource;

  const building = Building(
    id: 'LIB',
    code: 'LIB',
    name: 'Library',
    latitude: -33.7756,
    longitude: 151.1131,
  );

  const origin = LocationSample(latitude: -33.7738, longitude: 151.1127);

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockSupabaseClient = MockSupabaseClient();
    mockAuthClient = MockGoTrueClient();

    when(() => mockSupabaseClient.auth).thenReturn(mockAuthClient);
    when(() => mockAuthClient.currentSession).thenReturn(null);

    remoteSource = MapsRoutesRemoteSource(
      httpClient: mockHttpClient,
      supabaseClient: mockSupabaseClient,
    );

    registerFallbackValue(Uri());
  });

  group('MapsRoutesRemoteSource', () {
    test('getRoute returns MapRoute on 200 success', () async {
      // Arrange
      final successResponse = {
        'distanceMeters': 250,
        'durationSeconds': 180,
        'encodedPolyline': 'abc_123',
        'points': [
          {'lat': -33.7738, 'lng': 151.1127},
          {'lat': -33.7756, 'lng': 151.1131},
        ],
        'instructions': [
          {'instruction': 'Head south', 'distanceMeters': 250},
        ],
      };

      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(jsonEncode(successResponse), 200),
      );

      // Act
      final route = await remoteSource.getRoute(
        renderer: MapRendererType.campus,
        origin: origin,
        destination: building,
        travelMode: TravelMode.walk,
      );

      // Assert
      expect(route.distanceMeters, 250);
      expect(route.encodedPolyline, 'abc_123');
      expect(route.instructions.first.text, 'Head south');
    });

    test('getRoute throws StateError on 400 failure', () async {
      // Arrange
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async =>
            http.Response(jsonEncode({'error': 'Invalid request'}), 400),
      );

      // Act & Assert
      expect(
        () => remoteSource.getRoute(
          renderer: MapRendererType.campus,
          origin: origin,
          destination: building,
          travelMode: TravelMode.walk,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'getRoute throws StateError when building has no coordinates',
      () async {
        // Arrange
        const invalidBuilding = Building(id: 'X', code: 'X', name: 'Unknown');

        // Act & Assert
        expect(
          () => remoteSource.getRoute(
            renderer: MapRendererType.campus,
            origin: origin,
            destination: invalidBuilding,
            travelMode: TravelMode.walk,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Selected building is missing routing coordinates.'),
            ),
          ),
        );
      },
    );

    test('getRoute handles Directions API error format', () async {
      // Arrange
      final errorResponse = {'status': 'ZERO_RESULTS', 'routes': []};

      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(errorResponse), 200));

      // Act & Assert
      expect(
        () => remoteSource.getRoute(
          renderer: MapRendererType.google,
          origin: origin,
          destination: building,
          travelMode: TravelMode.walk,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'No routes were returned by the routing service (status: ZERO_RESULTS).',
            ),
          ),
        ),
      );
    });

    test('getRoute includes Authorization header if session exists', () async {
      // Arrange
      final mockSession = MockSession();
      when(() => mockSession.accessToken).thenReturn('fake-token');
      when(() => mockAuthClient.currentSession).thenReturn(mockSession);

      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('{"routes":[]}', 200));

      // Act & Assert (ignoring result, checking headers)
      try {
        await remoteSource.getRoute(
          renderer: MapRendererType.google,
          origin: origin,
          destination: building,
          travelMode: TravelMode.walk,
        );
      } catch (_) {}

      verify(
        () => mockHttpClient.post(
          any(),
          headers: any(
            named: 'headers',
            that: containsPair('Authorization', 'Bearer fake-token'),
          ),
          body: any(named: 'body'),
        ),
      ).called(1);
    });
  });

  // Every failure used to surface as "No route available", hiding an expired
  // server-side Google Routes key behind the same message as a real no-route.
  group('route failure classification', () {
    void stubResponse(int status, Map<String, dynamic> body) {
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(body), status));
    }

    Future<RouteFailureKind> failureKind() async {
      try {
        await remoteSource.getRoute(
          renderer: MapRendererType.google,
          origin: origin,
          destination: building,
          travelMode: TravelMode.drive,
        );
      } on RouteFailure catch (e) {
        return e.kind;
      }
      fail('expected a RouteFailure');
    }

    test(
      'an expired server key from a pre-code deployment is configuration',
      () async {
        stubResponse(500, {
          'error': 'API key expired. Please renew the API key.',
        });
        expect(await failureKind(), RouteFailureKind.configuration);
      },
    );

    test('ROUTING_AUTH is configuration', () async {
      stubResponse(502, {'error': 'denied', 'code': 'ROUTING_AUTH'});
      expect(await failureKind(), RouteFailureKind.configuration);
    });

    test('NO_ROUTE is a genuine no-route', () async {
      stubResponse(404, {'error': 'No route', 'code': 'NO_ROUTE'});
      expect(await failureKind(), RouteFailureKind.noRoute);
    });

    test('an unsupported campus mode is a no-route', () async {
      stubResponse(400, {'error': 'WALK only', 'code': 'MODE_UNSUPPORTED'});
      expect(await failureKind(), RouteFailureKind.noRoute);
    });

    test('an upstream failure is service unavailable', () async {
      stubResponse(502, {'error': 'boom', 'code': 'ROUTING_UPSTREAM'});
      expect(await failureKind(), RouteFailureKind.serviceUnavailable);
    });

    test('a generic 500 is service unavailable', () async {
      stubResponse(500, {'error': 'Campus routing service error'});
      expect(await failureKind(), RouteFailureKind.serviceUnavailable);
    });

    test('a server-side timeout is a network failure', () async {
      stubResponse(504, {'error': 'timed out', 'code': 'ROUTING_TIMEOUT'});
      expect(await failureKind(), RouteFailureKind.network);
    });

    test('an unreachable backend is a network failure', () async {
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(http.ClientException('Connection refused'));
      expect(await failureKind(), RouteFailureKind.network);
    });
  });
}

class MockSession extends Mock implements Session {}
