import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/presentation/pages/map_page.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class _FakeSettingsController extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

class _FakeMapRepository implements MapRepository {
  _FakeMapRepository({required this.buildings});

  final List<Building> buildings;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<LocationPermissionState> ensureLocationPermission() async {
    return LocationPermissionState.granted;
  }

  @override
  Future<List<Building>> getBuildings({bool forceRefresh = false}) async {
    return buildings;
  }

  @override
  Future<LocationSample?> getCurrentLocation() async {
    return const LocationSample(latitude: -33.77388, longitude: 151.11275);
  }

  @override
  Future<MapRoute> getRoute({
    required LocationSample origin,
    required Building destination,
    required TravelMode travelMode,
  }) async {
    return MapRoute(
      travelMode: travelMode,
      distanceMeters: 100,
      durationSeconds: 60,
      encodedPolyline: '',
      instructions: const [],
    );
  }

  @override
  Stream<LocationSample> watchLocation() => const Stream.empty();
}

void main() {
  final buildingA = Building.fromJson({
    'id': 'BLD-A',
    'code': 'BLDA',
    'name': 'Building A',
    'location': {'lat': -33.775, 'lng': 151.113},
    'category': 'academic',
  });

  final buildingB = Building.fromJson({
    'id': 'BLD-B',
    'code': 'BLDB',
    'name': 'Building B',
    'location': {'lat': -33.776, 'lng': 151.114},
    'category': 'academic',
  });

  late _FakeMapRepository fakeRepository;

  setUp(() {
    fakeRepository = _FakeMapRepository(buildings: [buildingA, buildingB]);
  });

  Widget buildTestApp({required GoRouter router}) {
    return ProviderScope(
      overrides: [
        mapRepositoryProvider.overrideWithValue(fakeRepository),
        settingsControllerProvider.overrideWith(
          () => _FakeSettingsController(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets(
    'MapPage parses meet coordinates, selects meet point, keeps path as /map, and preserves selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/map',
        routes: [
          GoRoute(
            path: '/map',
            name: RouteNames.map,
            builder: (context, state) => MapPage(
              initialSearchQuery: state.uri.queryParameters['q'],
              meetLat: double.tryParse(state.uri.queryParameters['lat'] ?? ''),
              meetLng: double.tryParse(state.uri.queryParameters['lng'] ?? ''),
            ),
            routes: [
              GoRoute(
                path: 'building/:buildingId',
                name: RouteNames.buildingDetail,
                builder: (context, state) => MapPage(
                  initialBuildingId: state.pathParameters['buildingId'],
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final element = tester.element(find.byType(MapPage));
      final container = ProviderScope.containerOf(element);

      router.go('/map?lat=-33.77380&lng=151.11260');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final selected = container
          .read(mapControllerProvider)
          .value!
          .selectedBuilding;
      expect(selected, isNotNull);
      expect(selected!.id, startsWith('meet_'));
      expect(selected.latitude, equals(-33.77380));
      expect(selected.longitude, equals(151.11260));

      expect(router.routeInformationProvider.value.uri.path, equals('/map'));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        container.read(mapControllerProvider).value!.selectedBuilding?.id,
        startsWith('meet_'),
      );
    },
  );

  testWidgets('MapPage selects building via query param and keeps /map path', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          name: RouteNames.map,
          builder: (context, state) => MapPage(
            initialBuildingId: state.uri.queryParameters['building'],
            initialSearchQuery: state.uri.queryParameters['q'],
            meetLat: double.tryParse(state.uri.queryParameters['lat'] ?? ''),
            meetLng: double.tryParse(state.uri.queryParameters['lng'] ?? ''),
          ),
          routes: [
            GoRoute(
              path: 'building/:buildingId',
              name: RouteNames.buildingDetail,
              builder: (context, state) => MapPage(
                initialBuildingId: state.pathParameters['buildingId'],
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(router: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final element = tester.element(find.byType(MapPage));
    final container = ProviderScope.containerOf(element);

    router.go('/map?building=BLD-A');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final selected = container
        .read(mapControllerProvider)
        .value!
        .selectedBuilding;
    expect(selected, isNotNull);
    expect(selected!.id, equals('BLD-A'));
    expect(selected.code, equals('BLDA'));

    expect(router.routeInformationProvider.value.uri.path, equals('/map'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      container.read(mapControllerProvider).value!.selectedBuilding?.id,
      equals('BLD-A'),
    );
  });

  testWidgets('MapPage selects building from query param', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          name: RouteNames.map,
          builder: (context, state) => MapPage(
            initialBuildingId: state.uri.queryParameters['building'],
            initialSearchQuery: state.uri.queryParameters['q'],
            meetLat: double.tryParse(state.uri.queryParameters['lat'] ?? ''),
            meetLng: double.tryParse(state.uri.queryParameters['lng'] ?? ''),
          ),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(router: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final element = tester.element(find.byType(MapPage));
    final container = ProviderScope.containerOf(element);

    router.go('/map?building=BLD-A');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final mapState = container.read(mapControllerProvider).value!;
    expect(mapState.selectedBuilding?.id, equals('BLD-A'));
    expect(mapState.isNavigating, isFalse);
  });

  testWidgets('MapPage keeps building selected on re-navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          name: RouteNames.map,
          builder: (context, state) => MapPage(
            initialBuildingId: state.uri.queryParameters['building'],
            initialSearchQuery: state.uri.queryParameters['q'],
            meetLat: double.tryParse(state.uri.queryParameters['lat'] ?? ''),
            meetLng: double.tryParse(state.uri.queryParameters['lng'] ?? ''),
          ),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(router: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final element = tester.element(find.byType(MapPage));
    final container = ProviderScope.containerOf(element);

    router.go('/map?building=BLD-A');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    var mapState = container.read(mapControllerProvider).value!;
    expect(mapState.selectedBuilding?.id, equals('BLD-A'));
    expect(mapState.route, isNull);
    expect(mapState.isNavigating, isFalse);

    router.go('/map?building=BLD-A');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    mapState = container.read(mapControllerProvider).value!;
    expect(mapState.selectedBuilding?.id, equals('BLD-A'));
    expect(mapState.isNavigating, isFalse);
  });

  testWidgets(
    'closing the building card hides it but keeps the pin and the route',
    (tester) async {
      // Reported: pressing X on the building card took the user "back to the
      // previous window". It cleared the selection, which dropped the map pin
      // and drove a goNamed() back to /map. Closing the card should only
      // close the card — the building stays pinned so it can be walked to.
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/map',
        routes: [
          GoRoute(
            path: '/map',
            name: RouteNames.map,
            builder: (context, state) => MapPage(
              initialBuildingId: state.uri.queryParameters['building'],
            ),
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final element = tester.element(find.byType(MapPage));
      final container = ProviderScope.containerOf(element);

      router.go('/map?building=BLD-A');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // The card is up, naming the building.
      expect(find.text('Building A'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Card gone...
      expect(find.text('Building A'), findsNothing);
      // ...but the building is still selected, so its pin is still on the map.
      expect(
        container.read(mapControllerProvider).value!.selectedBuilding?.id,
        equals('BLD-A'),
        reason: 'closing the card must not clear the selection',
      );
      // ...and we did not navigate anywhere.
      expect(
        router.routeInformationProvider.value.uri.path,
        equals('/map'),
        reason: 'closing the card must not pop back to a previous screen',
      );
    },
  );

  testWidgets('selecting a different building brings the card back', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          name: RouteNames.map,
          builder: (context, state) =>
              MapPage(initialBuildingId: state.uri.queryParameters['building']),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(router: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    router.go('/map?building=BLD-A');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Building A'), findsNothing);

    // Dismissing one building must not suppress the next one's card.
    router.go('/map?building=BLD-B');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Building B'), findsOneWidget);
  });
}
