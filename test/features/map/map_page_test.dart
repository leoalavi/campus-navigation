import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/app/router/route_names.dart';
import 'package:mq_navigation/app/router/shell_chrome_provider.dart';
import 'package:mq_navigation/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_navigation/features/map/domain/entities/building.dart';
import 'package:mq_navigation/features/map/domain/entities/map_renderer_type.dart';
import 'package:mq_navigation/features/map/domain/entities/route_leg.dart';
import 'package:mq_navigation/features/map/presentation/pages/map_page.dart';
import 'package:mq_navigation/features/map/data/datasources/location_source.dart';
import 'package:mq_navigation/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_navigation/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_navigation/features/map/presentation/widgets/building_actions_sheet.dart';
import 'package:mq_navigation/features/map/presentation/widgets/building_search_sheet.dart';
import 'package:mq_navigation/shared/models/user_preferences.dart';

class _FakeSettingsController extends SettingsController {
  @override
  Future<UserPreferences> build() async =>
      const UserPreferences(defaultRenderer: MapRendererType.campus);
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
    required MapRendererType renderer,
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

      // Navigate to meet coordinates
      router.go('/map?lat=-33.77380&lng=151.11260');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Expect a meet point building to be selected
      final selected = container
          .read(mapControllerProvider)
          .value!
          .selectedBuilding;
      expect(selected, isNotNull);
      expect(selected!.id, startsWith('meet_'));
      expect(selected.latitude, equals(-33.77380));
      expect(selected.longitude, equals(151.11260));

      // Route path should remain /map (with query params) rather than pushing buildingDetail path
      expect(router.routeInformationProvider.value.uri.path, equals('/map'));

      // Re-trigger pump to ensure post-frame callback back-navigation detector does not clear it
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

    // Navigate to select building via query param
    router.go('/map?building=BLD-A');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Expect Building A to be selected
    final selected = container
        .read(mapControllerProvider)
        .value!
        .selectedBuilding;
    expect(selected, isNotNull);
    expect(selected!.id, equals('BLD-A'));
    expect(selected.code, equals('BLDA'));

    // Route path should remain /map (with query params) rather than pushing buildingDetail path
    expect(router.routeInformationProvider.value.uri.path, equals('/map'));

    // Verify selection is preserved after re-pump (post-frame back-navigation
    // detector should not clear it because building query param is present)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      container.read(mapControllerProvider).value!.selectedBuilding?.id,
      equals('BLD-A'),
    );
  });

  testWidgets(
    'MapPage selects building and loads route preview when preview=route query param is set',
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
              initialBuildingId: state.uri.queryParameters['building'],
              autoPreviewRoute: state.uri.queryParameters['preview'] == 'route',
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

      // Navigate to select building and start navigation via query param
      router.go('/map?building=BLD-A&preview=route');
      await tester.pump();
      // Wait for the async post-frame callback (loadRoute)
      await tester.pump(const Duration(milliseconds: 200));

      final mapState = container.read(mapControllerProvider).value!;
      expect(mapState.selectedBuilding?.id, equals('BLD-A'));
      expect(mapState.route, isNotNull);
      expect(mapState.isNavigating, isFalse);
    },
  );

  testWidgets(
    'MapPage loads route preview on building already selected when preview=route is set',
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
              initialBuildingId: state.uri.queryParameters['building'],
              autoPreviewRoute: state.uri.queryParameters['preview'] == 'route',
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

      // First navigate to select the building without previewing the route
      router.go('/map?building=BLD-A');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      var mapState = container.read(mapControllerProvider).value!;
      expect(mapState.selectedBuilding?.id, equals('BLD-A'));
      expect(mapState.route, isNull);
      expect(mapState.isNavigating, isFalse);

      // Now navigate with preview=route on the already selected building
      router.go('/map?building=BLD-A&preview=route');
      await tester.pump();
      // Wait for the async post-frame callback to trigger loadRoute
      await tester.pump(const Duration(milliseconds: 200));

      mapState = container.read(mapControllerProvider).value!;
      expect(mapState.selectedBuilding?.id, equals('BLD-A'));
      expect(mapState.route, isNotNull);
      expect(mapState.isNavigating, isFalse);
    },
  );

  testWidgets('search hides shell chrome and cancel clears transient state', (
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
          builder: (context, state) => const MapPage(),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(router: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapPage)),
    );
    expect(container.read(bottomNavVisibleProvider), isTrue);

    await tester.tap(find.text('Search buildings...').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BuildingSearchSheet), findsOneWidget);
    expect(container.read(bottomNavVisibleProvider), isFalse);

    await tester.enterText(find.byType(TextField), 'No matching building');
    await tester.pump();
    expect(
      container.read(mapControllerProvider).value!.searchQuery,
      'No matching building',
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final afterClose = container.read(mapControllerProvider).value!;
    expect(afterClose.searchQuery, isEmpty);
    expect(afterClose.selectedBuilding, isNull);
    expect(container.read(bottomNavVisibleProvider), isTrue);

    // Repeat the lifecycle to catch leaked shell-chrome reference counts.
    await tester.tap(find.text('Search buildings...').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(bottomNavVisibleProvider), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(bottomNavVisibleProvider), isTrue);
    expect(container.read(shellChromeProvider), 0);
  });

  testWidgets('selecting a search result stays temporary until confirmed', (
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
          builder: (context, state) => const MapPage(),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(router: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapPage)),
    );

    await tester.tap(find.text('Search buildings...').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), buildingA.name);
    await tester.pump();
    expect(container.read(mapControllerProvider).value!.searchResults, [
      buildingA,
    ]);

    await tester.tap(find.text(buildingA.name).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BuildingActionsSheet), findsOneWidget);
    final whileChoosingAction = container.read(mapControllerProvider).value!;
    expect(whileChoosingAction.searchQuery, isEmpty);
    expect(whileChoosingAction.selectedBuilding, isNull);
    expect(container.read(bottomNavVisibleProvider), isFalse);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(bottomNavVisibleProvider), isTrue);
    expect(
      container.read(mapControllerProvider).value!.selectedBuilding,
      isNull,
    );
  });

  testWidgets('every Quick Access sheet has exactly one drag handle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const quickAccessTags = [
      'student services',
      'faculty',
      'campus hub',
      'food',
      'parking',
    ];
    fakeRepository = _FakeMapRepository(
      buildings: const [
        Building(
          id: 'QA-1',
          code: 'QA1',
          name: 'Quick Access One',
          latitude: -33.775,
          longitude: 151.113,
          tags: quickAccessTags,
          facultyGroup: FacultyGroup.arts,
          studentServicesGroups: [StudentServicesGroup.support],
          campusHubGroups: [CampusHubGroup.study],
        ),
        Building(
          id: 'QA-2',
          code: 'QA2',
          name: 'Quick Access Two',
          latitude: -33.776,
          longitude: 151.114,
          tags: quickAccessTags,
          facultyGroup: FacultyGroup.business,
          studentServicesGroups: [StudentServicesGroup.admin],
          campusHubGroups: [CampusHubGroup.sport],
        ),
      ],
    );

    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          name: RouteNames.map,
          builder: (context, state) => const MapPage(),
        ),
      ],
    );
    await tester.pumpWidget(buildTestApp(router: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapPage)),
    );

    final handleBars = find.byWidgetPredicate((widget) {
      if (widget is! Container || widget.constraints == null) return false;
      final constraints = widget.constraints!;
      final isParentHandle =
          constraints.minWidth == 36 &&
          constraints.maxWidth == 36 &&
          constraints.minHeight == 4 &&
          constraints.maxHeight == 4;
      final isLegacyChildHandle =
          constraints.minWidth == 48 &&
          constraints.maxWidth == 48 &&
          constraints.minHeight == 5 &&
          constraints.maxHeight == 5;
      return isParentHandle || isLegacyChildHandle;
    });

    for (final label in const [
      'Student Services',
      'Faculty',
      'Campus Hub',
      'Food & Drink',
      'Parking',
    ]) {
      await tester.tap(find.text(label).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        handleBars,
        findsOneWidget,
        reason: '$label duplicated its handle',
      );

      container.read(mapControllerProvider.notifier).clearCategoryBrowse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}
