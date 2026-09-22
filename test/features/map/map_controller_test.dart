import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/features/map/data/datasources/location_source.dart';
import 'package:mq_navigation/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_navigation/features/map/domain/entities/building.dart';
import 'package:mq_navigation/features/map/domain/entities/map_renderer_type.dart';
import 'package:mq_navigation/features/map/domain/entities/nav_instruction.dart';
import 'package:mq_navigation/features/map/domain/entities/route_leg.dart';
import 'package:mq_navigation/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_navigation/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_navigation/shared/models/user_preferences.dart';

void main() {
  group('MapController', () {
    final building = Building.fromJson({
      'id': 'LIB',
      'name': 'Waranara Library',
      'location': {'lat': -33.7756994, 'lng': 151.1131306},
      'entranceLocation': {'lat': -33.7754, 'lng': 151.11325},
      'category': 'academic',
    });
    final secondBuilding = Building.fromJson({
      'id': '18WW',
      'name': '18 Wally\'s Walk',
      'location': {'lat': -33.7739781, 'lng': 151.1126116},
      'entranceLocation': {'lat': -33.77388, 'lng': 151.11275},
      'category': 'services',
    });

    test(
      'defaults to campus renderer and preserves selection when switching',
      () async {
        final repository = _FakeMapRepository(buildings: [building]);
        final container = ProviderContainer(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repository),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsController(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final initialState = await container.read(mapControllerProvider.future);
        expect(initialState.renderer, MapRendererType.campus);

        final notifier = container.read(mapControllerProvider.notifier);
        notifier.selectBuilding(building);
        notifier.setRenderer(MapRendererType.google);

        final state = container.read(mapControllerProvider).value!;
        expect(state.renderer, MapRendererType.google);
        expect(state.selectedBuilding, building);
      },
    );

    test('passes active renderer through route loading', () async {
      final repository = _FakeMapRepository(buildings: [building]);
      final container = ProviderContainer(
        overrides: [
          mapRepositoryProvider.overrideWithValue(repository),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mapControllerProvider.future);
      final notifier = container.read(mapControllerProvider.notifier);

      notifier.selectBuilding(building);
      notifier.setRenderer(MapRendererType.google);
      await notifier.loadRoute();

      expect(repository.lastRenderer, MapRendererType.google);
      // loadRoute() no longer auto-starts navigation; explicit startNavigation() required.
      expect(
        container.read(mapControllerProvider).value!.isNavigating,
        isFalse,
      );

      notifier.startNavigation();
      expect(container.read(mapControllerProvider).value!.isNavigating, isTrue);
    });

    test('coerces unsupported campus travel modes to walk', () async {
      final repository = _FakeMapRepository(buildings: [building]);
      final container = ProviderContainer(
        overrides: [
          mapRepositoryProvider.overrideWithValue(repository),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mapControllerProvider.future);
      final notifier = container.read(mapControllerProvider.notifier);

      await notifier.setTravelMode(TravelMode.drive);
      final driveState = container.read(mapControllerProvider).value!;
      expect(driveState.travelMode, TravelMode.walk);
    });

    test('forces walk mode when switching back to campus renderer', () async {
      final repository = _FakeMapRepository(buildings: [building]);
      final container = ProviderContainer(
        overrides: [
          mapRepositoryProvider.overrideWithValue(repository),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mapControllerProvider.future);
      final notifier = container.read(mapControllerProvider.notifier);

      notifier.setRenderer(MapRendererType.google);
      await notifier.setTravelMode(TravelMode.transit);
      notifier.setRenderer(MapRendererType.campus);

      final state = container.read(mapControllerProvider).value!;
      expect(state.renderer, MapRendererType.campus);
      expect(state.travelMode, TravelMode.walk);
    });

    test('ignores stale route responses after destination changes', () async {
      final repository = _FakeMapRepository(
        buildings: [building, secondBuilding],
      );
      final completer = Completer<MapRoute>();
      repository.pendingRouteCompleter = completer;

      final container = ProviderContainer(
        overrides: [
          mapRepositoryProvider.overrideWithValue(repository),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mapControllerProvider.future);
      final notifier = container.read(mapControllerProvider.notifier);

      notifier.selectBuilding(building);
      final loadRouteFuture = notifier.loadRoute();

      notifier.selectBuilding(secondBuilding);
      completer.complete(
        MapRoute(
          travelMode: TravelMode.walk,
          distanceMeters: 220,
          durationSeconds: 180,
          encodedPolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
          instructions: const [
            NavInstruction(text: 'Head north', distanceMeters: 80),
          ],
        ),
      );
      await loadRouteFuture;

      final state = container.read(mapControllerProvider).value!;
      expect(state.selectedBuilding, secondBuilding);
      expect(state.route, isNull);
      expect(state.isLoadingRoute, isFalse);
      expect(state.isNavigating, isFalse);
    });

    test(
      'surfaces permission errors when route loading has no location',
      () async {
        final repository = _FakeMapRepository(
          buildings: [building],
          permissionState: LocationPermissionState.denied,
          currentLocation: null,
        );
        final container = ProviderContainer(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repository),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsController(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(mapControllerProvider.future);
        final notifier = container.read(mapControllerProvider.notifier);

        notifier.selectBuilding(building);
        await notifier.loadRoute();

        final state = container.read(mapControllerProvider).value!;
        expect(state.error, MapStateError.locationPermissionRequired);
        expect(state.isLoadingRoute, isFalse);
        expect(state.route, isNull);
      },
    );

    test('increments location center token when center is requested', () async {
      final repository = _FakeMapRepository(buildings: [building]);
      final container = ProviderContainer(
        overrides: [
          mapRepositoryProvider.overrideWithValue(repository),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mapControllerProvider.future);
      final notifier = container.read(mapControllerProvider.notifier);
      final before = container.read(mapControllerProvider).value!;

      await notifier.centerOnCurrentLocation();

      final after = container.read(mapControllerProvider).value!;
      expect(
        after.locationCenterRequestToken,
        before.locationCenterRequestToken + 1,
      );
      expect(after.currentLocation, isNotNull);
    });

    test(
      'centerOnCurrentLocation preserves newer state created while awaiting location',
      () async {
        final repository = _FakeMapRepository(
          buildings: [building, secondBuilding],
        );
        final permissionCompleter = Completer<LocationPermissionState>();
        final locationCompleter = Completer<LocationSample?>();
        repository.pendingPermissionCompleter = permissionCompleter;
        repository.pendingLocationCompleter = locationCompleter;
        final container = ProviderContainer(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repository),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsController(),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Build() now calls ensureLocationPermission + getCurrentLocation during
        // init. Complete the pending ones for build(), then set new ones for
        // centerOnCurrentLocation to test async preservation.
        permissionCompleter.complete(LocationPermissionState.granted);
        locationCompleter.complete(
          const LocationSample(
            latitude: -33.77388,
            longitude: 151.11275,
            accuracy: 5,
          ),
        );
        await container.read(mapControllerProvider.future);
        final notifier = container.read(mapControllerProvider.notifier);

        final permissionCompleter2 = Completer<LocationPermissionState>();
        final locationCompleter2 = Completer<LocationSample?>();
        repository.pendingPermissionCompleter = permissionCompleter2;
        repository.pendingLocationCompleter = locationCompleter2;

        final centerFuture = notifier.centerOnCurrentLocation();

        // While locate-me is waiting on async permission/location, user selects
        // another building. The locate-me completion must not roll state back.
        notifier.selectBuilding(secondBuilding);

        permissionCompleter2.complete(LocationPermissionState.granted);
        locationCompleter2.complete(
          const LocationSample(
            latitude: -33.774,
            longitude: 151.113,
            accuracy: 5,
          ),
        );
        await centerFuture;

        final state = container.read(mapControllerProvider).value!;
        expect(state.selectedBuilding, secondBuilding);
        expect(state.currentLocation, isNotNull);
      },
    );

    test(
      'marks arrival and stops navigation when user reaches destination',
      () async {
        final locationStream = StreamController<LocationSample>.broadcast();
        addTearDown(locationStream.close);
        final repository = _FakeMapRepository(
          buildings: [building],
          locationStream: locationStream.stream,
        );
        final container = ProviderContainer(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repository),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsController(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(mapControllerProvider.future);
        final notifier = container.read(mapControllerProvider.notifier);

        notifier.selectBuilding(building);
        await notifier.loadRoute();
        notifier.startNavigation();

        locationStream.add(
          const LocationSample(
            latitude: -33.7754,
            longitude: 151.11325,
            accuracy: 5,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final state = container.read(mapControllerProvider).value!;
        expect(state.hasArrived, isTrue);
        expect(state.isNavigating, isFalse);
      },
    );

    test('recalculates when navigation goes sufficiently off route', () async {
      final locationStream = StreamController<LocationSample>.broadcast();
      addTearDown(locationStream.close);
      final repository = _FakeMapRepository(
        buildings: [building],
        locationStream: locationStream.stream,
      );
      final container = ProviderContainer(
        overrides: [
          mapRepositoryProvider.overrideWithValue(repository),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mapControllerProvider.future);
      final notifier = container.read(mapControllerProvider.notifier);

      notifier.selectBuilding(building);
      await notifier.loadRoute();
      notifier.startNavigation();
      final initialRouteCalls = repository.routeCallCount;

      locationStream.add(
        const LocationSample(
          latitude: -33.7700,
          longitude: 151.1200,
          accuracy: 5,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.routeCallCount, greaterThan(initialRouteCalls));
    });

    test(
      'search session never replaces or clears a confirmed destination',
      () async {
        final repository = _FakeMapRepository(
          buildings: [building, secondBuilding],
        );
        final container = ProviderContainer(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repository),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsController(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(mapControllerProvider.future);
        final notifier = container.read(mapControllerProvider.notifier);

        notifier.selectBuilding(building);
        await notifier.loadRoute();
        final confirmedRoute = container
            .read(mapControllerProvider)
            .value!
            .route;

        notifier.updateSearchQuery(secondBuilding.name);
        final duringSearch = container.read(mapControllerProvider).value!;
        expect(duringSearch.searchQuery, secondBuilding.name);
        expect(duringSearch.selectedBuilding, building);
        expect(duringSearch.route, same(confirmedRoute));

        notifier.clearSearchSession();
        final afterClose = container.read(mapControllerProvider).value!;
        expect(afterClose.searchQuery, isEmpty);
        expect(afterClose.selectedBuilding, building);
        expect(afterClose.route, same(confirmedRoute));
      },
    );

    test('closing an unselected search clears its temporary results', () async {
      final repository = _FakeMapRepository(
        buildings: [building, secondBuilding],
      );
      final container = ProviderContainer(
        overrides: [
          mapRepositoryProvider.overrideWithValue(repository),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mapControllerProvider.future);
      final notifier = container.read(mapControllerProvider.notifier);

      notifier.updateSearchQuery(secondBuilding.name);
      expect(
        container.read(mapControllerProvider).value!.searchResults,
        contains(secondBuilding),
      );

      notifier.clearSearchSession();
      final afterClose = container.read(mapControllerProvider).value!;
      expect(afterClose.searchQuery, isEmpty);
      expect(afterClose.selectedBuilding, isNull);
      expect(afterClose.searchResults, hasLength(2));
      expect(afterClose.searchResults, containsAll([building, secondBuilding]));

      notifier.setRenderer(MapRendererType.google);
      expect(
        container.read(mapControllerProvider).value!.renderer,
        MapRendererType.google,
      );
      notifier.setRenderer(MapRendererType.campus);
      final afterRendererRoundTrip = container
          .read(mapControllerProvider)
          .value!;
      expect(afterRendererRoundTrip.renderer, MapRendererType.campus);
      expect(afterRendererRoundTrip.searchQuery, isEmpty);
      expect(afterRendererRoundTrip.selectedBuilding, isNull);
    });

    test(
      'clearSelection from focused-with-query state preserves the query (back-to-list)',
      () async {
        // Repro of the focused → list back behavior: when a user is in
        // category browse mode AND has drilled into a specific
        // building, tapping close on the RoutePanel should return to
        // the category list — not wipe everything.
        final repository = _FakeMapRepository(
          buildings: [building, secondBuilding],
        );
        final container = ProviderContainer(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repository),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsController(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(mapControllerProvider.future);
        final notifier = container.read(mapControllerProvider.notifier);

        notifier.updateSearchQuery('library');
        notifier.selectBuilding(building);
        expect(
          container.read(mapControllerProvider).value!.selectedBuilding,
          building,
        );

        notifier.clearSelection();
        final after = container.read(mapControllerProvider).value!;
        expect(after.selectedBuilding, isNull);
        expect(
          after.searchQuery,
          'library',
          reason: 'Query preserved so the category list reappears',
        );
      },
    );

    test(
      'clearCategoryBrowse fully resets even when a query is active',
      () async {
        // The X button on the category list panel uses this method to
        // exit category browse entirely — distinct from clearSelection.
        final repository = _FakeMapRepository(buildings: [building]);
        final container = ProviderContainer(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repository),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsController(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(mapControllerProvider.future);
        final notifier = container.read(mapControllerProvider.notifier);

        notifier.updateSearchQuery('food');
        expect(
          container.read(mapControllerProvider).value!.searchQuery,
          'food',
        );

        notifier.clearCategoryBrowse();
        final after = container.read(mapControllerProvider).value!;
        expect(after.searchQuery, isEmpty);
        expect(after.selectedBuilding, isNull);
      },
    );
  });

  group('MapState', () {
    test('default activeOverlayIds is empty', () {
      const state = MapState(buildings: [], searchResults: []);
      expect(state.activeOverlayIds, isEmpty);
    });

    test('copyWith preserves activeOverlayIds', () {
      const state = MapState(
        buildings: [],
        searchResults: [],
        activeOverlayIds: {'parking', 'accessibility'},
      );
      final updated = state.copyWith(searchQuery: 'test');
      expect(updated.activeOverlayIds, {'parking', 'accessibility'});
    });

    test('copyWith can update activeOverlayIds', () {
      const state = MapState(buildings: [], searchResults: []);
      final updated = state.copyWith(activeOverlayIds: {'parking'});
      expect(updated.activeOverlayIds, {'parking'});
    });
  });
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

class _FakeMapRepository implements MapRepository {
  _FakeMapRepository({
    required this.buildings,
    this.permissionState = LocationPermissionState.granted,
    this.currentLocation = const LocationSample(
      latitude: -33.77388,
      longitude: 151.11275,
      accuracy: 8,
    ),
    Stream<LocationSample>? locationStream,
  }) : _locationStream = locationStream ?? const Stream<LocationSample>.empty();

  final List<Building> buildings;
  final LocationPermissionState permissionState;
  final LocationSample? currentLocation;
  final Stream<LocationSample> _locationStream;
  MapRendererType? lastRenderer;
  Completer<MapRoute>? pendingRouteCompleter;
  Completer<LocationPermissionState>? pendingPermissionCompleter;
  Completer<LocationSample?>? pendingLocationCompleter;
  int routeCallCount = 0;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<LocationPermissionState> ensureLocationPermission() async {
    final pending = pendingPermissionCompleter;
    if (pending != null) {
      pendingPermissionCompleter = null;
      return pending.future;
    }
    return permissionState;
  }

  @override
  Future<List<Building>> getBuildings({bool forceRefresh = false}) async {
    return buildings;
  }

  @override
  Future<LocationSample?> getCurrentLocation() async {
    final pending = pendingLocationCompleter;
    if (pending != null) {
      pendingLocationCompleter = null;
      return pending.future;
    }
    return currentLocation;
  }

  @override
  Future<MapRoute> getRoute({
    required MapRendererType renderer,
    required LocationSample origin,
    required Building destination,
    required TravelMode travelMode,
  }) async {
    routeCallCount += 1;
    lastRenderer = renderer;
    final pending = pendingRouteCompleter;
    if (pending != null) {
      pendingRouteCompleter = null;
      return pending.future;
    }
    return MapRoute(
      travelMode: travelMode,
      distanceMeters: 220,
      durationSeconds: 180,
      encodedPolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
      instructions: const [
        NavInstruction(text: 'Head north', distanceMeters: 80),
      ],
    );
  }

  @override
  Stream<LocationSample> watchLocation() => _locationStream;
}
