import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/router/active_shell_branch_index_provider.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/nav_instruction.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

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

    test('preserves selection when route loads', () async {
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

      final state = container.read(mapControllerProvider).value!;
      expect(state.selectedBuilding, building);
    });

    test('loads route and tracks navigation state', () async {
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
      await notifier.loadRoute();

      expect(
        container.read(mapControllerProvider).value!.isNavigating,
        isFalse,
      );

      notifier.startNavigation();
      expect(container.read(mapControllerProvider).value!.isNavigating, isTrue);
    });

    test('pauses location updates off-screen and resumes on return', () async {
      var listenCount = 0;
      var cancelCount = 0;
      final locations = StreamController<LocationSample>.broadcast(
        onListen: () => listenCount += 1,
        onCancel: () => cancelCount += 1,
      );
      addTearDown(locations.close);
      final repository = _FakeMapRepository(
        buildings: [building],
        locationStream: locations.stream,
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
      expect(listenCount, 1);

      container
          .read(activeShellBranchIndexProvider.notifier)
          .setIndex(ShellBranchIndex.settings);
      await Future<void>.delayed(Duration.zero);

      expect(cancelCount, 1);
      expect(locations.hasListener, isFalse);

      container
          .read(activeShellBranchIndexProvider.notifier)
          .setIndex(ShellBranchIndex.map);
      await Future<void>.delayed(Duration.zero);

      expect(listenCount, 2);
      expect(locations.hasListener, isTrue);
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

    test('forces walk mode when switching to campus', () async {
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

      await notifier.setTravelMode(TravelMode.transit);

      final state = container.read(mapControllerProvider).value!;
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
      'coalesces off-route samples while recalculation is pending',
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
        final initialRouteCalls = repository.routeCallCount;
        final pendingRoute = Completer<MapRoute>();
        repository.pendingRouteCompleter = pendingRoute;
        addTearDown(() {
          if (!pendingRoute.isCompleted) {
            pendingRoute.complete(_testRoute());
          }
        });

        const offRouteLocation = LocationSample(
          latitude: -33.7700,
          longitude: 151.1200,
          accuracy: 5,
        );
        locationStream.add(offRouteLocation);
        await _waitUntil(
          () => repository.routeCallCount == initialRouteCalls + 1,
        );
        locationStream.add(offRouteLocation);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(repository.routeCallCount, initialRouteCalls + 1);

        pendingRoute.complete(_testRoute());
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'clearSelection from focused-with-query state preserves the query (back-to-list)',
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

MapRoute _testRoute() {
  return MapRoute(
    travelMode: TravelMode.walk,
    distanceMeters: 220,
    durationSeconds: 180,
    encodedPolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
    instructions: const [
      NavInstruction(text: 'Head north', distanceMeters: 80),
    ],
  );
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not reached before the test deadline');
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
    required LocationSample origin,
    required Building destination,
    required TravelMode travelMode,
  }) async {
    routeCallCount += 1;
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
