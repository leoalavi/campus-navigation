import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/core/logging/app_logger.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/domain/services/building_search.dart';
import 'package:mq_journey/features/map/domain/services/geo_utils.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_view_helpers.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:url_launcher/url_launcher.dart';

enum MapStateError {
  routeUnavailable,
  locationServicesDisabled,
  locationPermissionBlocked,
  locationPermissionRequired,
  locationUnsupported,
  locationUnavailable,
}

@immutable
class MapState {
  const MapState({
    required this.buildings,
    required this.searchResults,
    this.selectedBuilding,
    this.currentLocation,
    this.route,
    this.searchQuery = '',
    this.travelMode = TravelMode.walk,
    this.permissionState = LocationPermissionState.denied,
    this.isNavigating = false,
    this.isLoadingRoute = false,
    this.hasArrived = false,
    this.locationCenterRequestToken = 0,
    this.activeOverlayIds = const {},
    this.error,
    this.selectedFacultyGroup,
    this.selectedStudentServicesGroup,
    this.selectedCampusHubGroup,
  });

  final List<Building> buildings;
  final List<Building> searchResults;
  final Building? selectedBuilding;
  final LocationSample? currentLocation;
  final MapRoute? route;
  final String searchQuery;
  final TravelMode travelMode;
  final LocationPermissionState permissionState;
  final bool isNavigating;
  final bool isLoadingRoute;
  final bool hasArrived;
  final int locationCenterRequestToken;
  final Set<String> activeOverlayIds;
  final MapStateError? error;

  final FacultyGroup? selectedFacultyGroup;
  final StudentServicesGroup? selectedStudentServicesGroup;
  final CampusHubGroup? selectedCampusHubGroup;

  MapState copyWith({
    List<Building>? buildings,
    List<Building>? searchResults,
    Building? selectedBuilding,
    bool clearSelectedBuilding = false,
    LocationSample? currentLocation,
    bool clearCurrentLocation = false,
    MapRoute? route,
    bool clearRoute = false,
    String? searchQuery,
    TravelMode? travelMode,
    LocationPermissionState? permissionState,
    bool? isNavigating,
    bool? isLoadingRoute,
    bool? hasArrived,
    int? locationCenterRequestToken,
    Set<String>? activeOverlayIds,
    MapStateError? error,
    bool clearError = false,
    FacultyGroup? selectedFacultyGroup,
    bool clearSelectedFacultyGroup = false,
    StudentServicesGroup? selectedStudentServicesGroup,
    bool clearSelectedStudentServicesGroup = false,
    CampusHubGroup? selectedCampusHubGroup,
    bool clearSelectedCampusHubGroup = false,
  }) {
    return MapState(
      buildings: buildings ?? this.buildings,
      searchResults: searchResults ?? this.searchResults,
      selectedBuilding: clearSelectedBuilding
          ? null
          : selectedBuilding ?? this.selectedBuilding,
      currentLocation: clearCurrentLocation
          ? null
          : currentLocation ?? this.currentLocation,
      route: clearRoute ? null : route ?? this.route,
      searchQuery: searchQuery ?? this.searchQuery,
      travelMode: travelMode ?? this.travelMode,
      permissionState: permissionState ?? this.permissionState,
      isNavigating: isNavigating ?? this.isNavigating,
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
      hasArrived: hasArrived ?? this.hasArrived,
      locationCenterRequestToken:
          locationCenterRequestToken ?? this.locationCenterRequestToken,
      activeOverlayIds: activeOverlayIds ?? this.activeOverlayIds,
      error: clearError ? null : error ?? this.error,
      selectedFacultyGroup: clearSelectedFacultyGroup
          ? null
          : selectedFacultyGroup ?? this.selectedFacultyGroup,
      selectedStudentServicesGroup: clearSelectedStudentServicesGroup
          ? null
          : selectedStudentServicesGroup ?? this.selectedStudentServicesGroup,
      selectedCampusHubGroup: clearSelectedCampusHubGroup
          ? null
          : selectedCampusHubGroup ?? this.selectedCampusHubGroup,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MapState &&
        listEquals(other.buildings, buildings) &&
        listEquals(other.searchResults, searchResults) &&
        other.selectedBuilding == selectedBuilding &&
        other.currentLocation == currentLocation &&
        other.route == route &&
        other.searchQuery == searchQuery &&
        other.travelMode == travelMode &&
        other.permissionState == permissionState &&
        other.isNavigating == isNavigating &&
        other.isLoadingRoute == isLoadingRoute &&
        other.hasArrived == hasArrived &&
        other.locationCenterRequestToken == locationCenterRequestToken &&
        setEquals(other.activeOverlayIds, activeOverlayIds) &&
        other.error == error &&
        other.selectedFacultyGroup == selectedFacultyGroup &&
        other.selectedStudentServicesGroup == selectedStudentServicesGroup &&
        other.selectedCampusHubGroup == selectedCampusHubGroup;
  }

  @override
  int get hashCode {
    return buildings.hashCode ^
        searchResults.hashCode ^
        selectedBuilding.hashCode ^
        currentLocation.hashCode ^
        route.hashCode ^
        searchQuery.hashCode ^
        travelMode.hashCode ^
        permissionState.hashCode ^
        isNavigating.hashCode ^
        isLoadingRoute.hashCode ^
        hasArrived.hashCode ^
        locationCenterRequestToken.hashCode ^
        activeOverlayIds.hashCode ^
        error.hashCode ^
        selectedFacultyGroup.hashCode ^
        selectedStudentServicesGroup.hashCode ^
        selectedCampusHubGroup.hashCode;
  }
}

final mapControllerProvider = AsyncNotifierProvider<MapController, MapState>(
  MapController.new,
);

class MapController extends AsyncNotifier<MapState> {
  static const _defaultVisibleBuildings = 15;
  static const _arrivalThresholdMetres = 30.0;
  static const _offRouteThresholdMetres = 50.0;

  StreamSubscription<LocationSample>? _locationSubscription;
  int _routeRequestVersion = 0;
  LocationSample? _lastRouteFetchLocation;
  DateTime? _lastNavDiagnosticsAt;

  @override
  Future<MapState> build() async {
    ref.onDispose(() => _locationSubscription?.cancel());
    final buildings = await ref.read(mapRepositoryProvider).getBuildings();

    ref.listen(settingsControllerProvider, (previous, next) {
      final nextPrefs = next.value;
      final currentMapState = state.value;
      if (nextPrefs == null || currentMapState == null) return;

      var updatedState = currentMapState;
      var changed = false;

      if (currentMapState.travelMode != nextPrefs.defaultTravelMode &&
          currentMapState.travelMode != TravelMode.walk) {
        _invalidateRouteRequest();
        updatedState = updatedState.copyWith(
          travelMode: TravelMode.walk,
          isLoadingRoute: false,
          isNavigating: false,
          hasArrived: false,
        );
        changed = true;
      }

      if (changed) {
        state = AsyncData(updatedState);
        if (updatedState.selectedBuilding != null &&
            currentMapState.route != null) {
          unawaited(loadRoute());
        }
      }
    });

    var initialPermission = LocationPermissionState.denied;
    LocationSample? initialLocation;
    try {
      initialPermission = await ref
          .read(mapRepositoryProvider)
          .ensureLocationPermission();
      if (initialPermission == LocationPermissionState.granted) {
        initialLocation = await ref
            .read(mapRepositoryProvider)
            .getCurrentLocation();
        if (initialLocation != null) {
          await _startLocationTracking();
        }
      }
    } catch (_) {}

    return MapState(
      buildings: buildings,
      searchResults: searchCampusBuildings(
        buildings,
        '',
      ).take(_defaultVisibleBuildings).toList(),
      travelMode: TravelMode.walk,
      permissionState: initialPermission,
      currentLocation: initialLocation,
    );
  }

  void updateSearchQuery(String query) {
    final current = state.value;
    if (current == null) {
      return;
    }

    final normalized = normalizeMapSearch(query);
    final rankedBuildings = searchCampusBuildings(
      current.buildings,
      normalized,
    );
    final searchResults = normalized.isEmpty
        ? rankedBuildings.take(_defaultVisibleBuildings).toList()
        : rankedBuildings
              .where((b) => scoreBuildingMatch(b, normalized) > 0)
              .toList();

    final exactMatch = searchResults.where((building) {
      return isStrongCampusMatch(building, normalized);
    }).toList();
    final shouldAutoSelect =
        exactMatch.length == 1 && searchResults.length == 1;
    final nextSelectedBuilding = shouldAutoSelect ? exactMatch.first : null;
    final selectionChanged =
        nextSelectedBuilding?.id != current.selectedBuilding?.id;

    if (selectionChanged) {
      _invalidateRouteRequest();
    }

    state = AsyncData(
      current.copyWith(
        searchQuery: query,
        searchResults: searchResults,
        selectedBuilding: nextSelectedBuilding,
        clearSelectedBuilding: !shouldAutoSelect,
        clearRoute: selectionChanged && current.route != null,
        isNavigating: selectionChanged ? false : current.isNavigating,
        isLoadingRoute: selectionChanged ? false : current.isLoadingRoute,
        clearError: true,
        clearSelectedFacultyGroup: true,
        clearSelectedStudentServicesGroup: true,
        clearSelectedCampusHubGroup: true,
      ),
    );
  }

  void selectFacultyGroup(FacultyGroup? group) {
    final current = state.value;
    if (current == null) {
      return;
    }
    if (current.searchQuery.trim().toLowerCase() != 'faculty') {
      return;
    }
    state = AsyncData(
      current.copyWith(
        selectedFacultyGroup: group,
        clearSelectedFacultyGroup: group == null,
        clearSelectedBuilding: true,
        clearRoute: true,
        isNavigating: false,
        hasArrived: false,
        isLoadingRoute: false,
        clearError: true,
      ),
    );
  }

  void selectStudentServicesGroup(StudentServicesGroup? group) {
    final current = state.value;
    if (current == null) {
      return;
    }
    if (current.searchQuery.trim().toLowerCase() != 'student services') {
      return;
    }
    state = AsyncData(
      current.copyWith(
        selectedStudentServicesGroup: group,
        clearSelectedStudentServicesGroup: group == null,
        clearSelectedBuilding: true,
        clearRoute: true,
        isNavigating: false,
        hasArrived: false,
        isLoadingRoute: false,
        clearError: true,
      ),
    );
  }

  void selectCampusHubGroup(CampusHubGroup? group) {
    final current = state.value;
    if (current == null) {
      return;
    }
    if (current.searchQuery.trim().toLowerCase() != 'campus hub') {
      return;
    }
    state = AsyncData(
      current.copyWith(
        selectedCampusHubGroup: group,
        clearSelectedCampusHubGroup: group == null,
        clearSelectedBuilding: true,
        clearRoute: true,
        isNavigating: false,
        hasArrived: false,
        isLoadingRoute: false,
        clearError: true,
      ),
    );
  }

  void selectBuilding(Building building) {
    final current = state.value;
    if (current == null) {
      return;
    }
    _invalidateRouteRequest();
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _lastRouteFetchLocation = null;
    state = AsyncData(
      current.copyWith(
        selectedBuilding: building,
        clearRoute: true,
        isNavigating: false,
        hasArrived: false,
        isLoadingRoute: false,
        clearError: true,
      ),
    );
  }

  void selectBuildingById(String buildingId) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final upperId = buildingId.toUpperCase();
    final building = current.buildings
        .where(
          (item) =>
              item.id.toUpperCase() == upperId ||
              item.code.toUpperCase() == upperId,
        )
        .firstOrNull;
    if (building != null) {
      selectBuilding(building);
    }
  }

  Future<void> selectMeetPoint({
    required double latitude,
    required double longitude,
  }) async {
    final current = state.value;
    if (current == null) {
      return;
    }

    final meetPoint = Building(
      code: '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      id: 'meet_${latitude}_$longitude',
      latitude: latitude,
      longitude: longitude,
      name: '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
    );

    selectBuilding(meetPoint);
    await loadRoute();
  }

  Future<void> loadRoute() async {
    final current = state.value;
    if (current?.selectedBuilding == null) {
      return;
    }
    final requestId = _beginRouteRequest();
    final selectedBuildingId = current!.selectedBuilding!.id;
    final travelMode = current.travelMode;

    state = AsyncData(current.copyWith(isLoadingRoute: true, clearError: true));

    final permissionState = await ref
        .read(mapRepositoryProvider)
        .ensureLocationPermission();

    final location = await ref.read(mapRepositoryProvider).getCurrentLocation();
    if (!_isRouteRequestCurrent(
      requestId,
      selectedBuildingId: selectedBuildingId,
      travelMode: travelMode,
    )) {
      return;
    }
    if (location == null) {
      final latest = state.value;
      if (latest == null) {
        return;
      }
      state = AsyncData(
        latest.copyWith(
          permissionState: permissionState,
          isLoadingRoute: false,
          error: _errorForPermission(permissionState),
        ),
      );
      return;
    }

    try {
      final route = await ref
          .read(mapRepositoryProvider)
          .getRoute(
            origin: location,
            destination: current.selectedBuilding!,
            travelMode: current.travelMode,
          );
      if (!_isRouteRequestCurrent(
        requestId,
        selectedBuildingId: selectedBuildingId,
        travelMode: travelMode,
      )) {
        return;
      }
      final latest = state.value;
      if (latest == null) {
        return;
      }
      _lastRouteFetchLocation = location;
      await _startLocationTracking();
      state = AsyncData(
        latest.copyWith(
          currentLocation: location,
          permissionState: permissionState,
          route: route,
          isLoadingRoute: false,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to load route', error, stackTrace);
      if (!_isRouteRequestCurrent(
        requestId,
        selectedBuildingId: selectedBuildingId,
        travelMode: travelMode,
      )) {
        return;
      }
      final latest = state.value;
      if (latest == null) {
        return;
      }
      state = AsyncData(
        latest.copyWith(
          currentLocation: location,
          permissionState: permissionState,
          isLoadingRoute: false,
          error: MapStateError.routeUnavailable,
        ),
      );
    }
  }

  Future<void> centerOnCurrentLocation() async {
    if (state.value == null) {
      return;
    }
    final permissionState = await ref
        .read(mapRepositoryProvider)
        .ensureLocationPermission();
    final location = await ref.read(mapRepositoryProvider).getCurrentLocation();
    final latest = state.value;
    if (latest == null) {
      return;
    }
    if (location == null) {
      state = AsyncData(
        latest.copyWith(
          permissionState: permissionState,
          error: _errorForPermission(permissionState),
        ),
      );
      return;
    }
    state = AsyncData(
      latest.copyWith(
        currentLocation: location,
        locationCenterRequestToken: latest.locationCenterRequestToken + 1,
        permissionState: permissionState,
        clearError: true,
      ),
    );
  }

  Future<void> setTravelMode(TravelMode travelMode) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    if (travelMode != TravelMode.walk) {
      travelMode = TravelMode.walk;
    }
    _invalidateRouteRequest();
    state = AsyncData(
      current.copyWith(
        travelMode: travelMode,
        isLoadingRoute: false,
        isNavigating: false,
        hasArrived: false,
      ),
    );
    if (current.selectedBuilding != null && current.route != null) {
      await loadRoute();
    }
  }

  void clearRoute() {
    final current = state.value;
    if (current == null) {
      return;
    }
    _invalidateRouteRequest();
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _lastRouteFetchLocation = null;
    state = AsyncData(
      current.copyWith(
        clearRoute: true,
        isNavigating: false,
        hasArrived: false,
        isLoadingRoute: false,
        clearError: true,
      ),
    );
  }

  void clearCategoryBrowse() {
    final current = state.value;
    if (current == null) {
      return;
    }
    _invalidateRouteRequest();
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _lastRouteFetchLocation = null;
    state = AsyncData(
      current.copyWith(
        clearSelectedBuilding: true,
        clearRoute: true,
        searchQuery: '',
        searchResults: searchCampusBuildings(
          current.buildings,
          '',
        ).take(_defaultVisibleBuildings).toList(),
        isNavigating: false,
        hasArrived: false,
        isLoadingRoute: false,
        clearError: true,
        clearSelectedFacultyGroup: true,
        clearSelectedStudentServicesGroup: true,
        clearSelectedCampusHubGroup: true,
      ),
    );
  }

  void clearSelection() {
    final current = state.value;
    if (current == null) {
      return;
    }
    _invalidateRouteRequest();
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _lastRouteFetchLocation = null;

    final hasActiveQuery = current.searchQuery.trim().isNotEmpty;
    if (hasActiveQuery) {
      state = AsyncData(
        current.copyWith(
          clearSelectedBuilding: true,
          clearRoute: true,
          isNavigating: false,
          hasArrived: false,
          isLoadingRoute: false,
          clearError: true,
        ),
      );
      return;
    }

    state = AsyncData(
      current.copyWith(
        clearSelectedBuilding: true,
        clearRoute: true,
        searchQuery: '',
        searchResults: searchCampusBuildings(
          current.buildings,
          '',
        ).take(_defaultVisibleBuildings).toList(),
        isNavigating: false,
        hasArrived: false,
        isLoadingRoute: false,
        clearError: true,
        clearSelectedFacultyGroup: true,
        clearSelectedStudentServicesGroup: true,
        clearSelectedCampusHubGroup: true,
      ),
    );
  }

  void startNavigation() {
    final current = state.value;
    if (current == null || current.route == null) {
      return;
    }
    AppLogger.info('Navigation started', {
      'destination': current.selectedBuilding?.id,
      'travelMode': current.travelMode.name,
    });
    state = AsyncData(
      current.copyWith(isNavigating: true, hasArrived: false, clearError: true),
    );
  }

  void stopNavigation() {
    final current = state.value;
    if (current == null) {
      return;
    }
    AppLogger.info('Navigation stopped', {
      'destination': current.selectedBuilding?.id,
    });
    state = AsyncData(current.copyWith(isNavigating: false, clearError: true));
  }

  void toggleOverlay(String id) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final ids = Set<String>.of(current.activeOverlayIds);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    state = AsyncData(current.copyWith(activeOverlayIds: ids));
  }

  void clearOverlays() {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(activeOverlayIds: const {}));
  }

  void dismissArrival() {
    clearSelection();
  }

  Future<void> openStreetView() async {
    final building = state.value?.selectedBuilding;
    if (building == null) return;
    final lat = building.routingLatitude ?? building.latitude;
    final lng = building.routingLongitude ?? building.longitude;
    if (lat == null || lng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/@$lat,$lng,3a,75y,0h,90t/data=!3m4!1e1!3m2!1s!2e0',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> openLocationSettings() {
    return ref.read(mapRepositoryProvider).openLocationSettings();
  }

  Future<void> openAppSettings() {
    return ref.read(mapRepositoryProvider).openAppSettings();
  }

  Future<void> _startLocationTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription = ref
        .read(mapRepositoryProvider)
        .watchLocation()
        .listen(
          (location) {
            final current = state.value;
            if (current == null) {
              return;
            }
            state = AsyncData(current.copyWith(currentLocation: location));

            final updated = state.value;
            if (updated != null &&
                updated.isNavigating &&
                updated.selectedBuilding != null) {
              _checkNavigationState(location);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            AppLogger.warning('Location stream error', error, stackTrace);
          },
        );
  }

  void _checkNavigationState(LocationSample location) {
    final current = state.value;
    if (current == null || !current.isNavigating) {
      return;
    }
    final destination = current.selectedBuilding;
    if (destination == null) {
      return;
    }
    final destLat = destination.routingLatitude;
    final destLng = destination.routingLongitude;
    if (destLat == null || destLng == null) {
      return;
    }

    final distToDestination = haversineMetres(
      lat1: location.latitude,
      lng1: location.longitude,
      lat2: destLat,
      lng2: destLng,
    );

    if (distToDestination <= _arrivalThresholdMetres) {
      _locationSubscription?.cancel();
      _locationSubscription = null;
      AppLogger.info('Navigation arrived', {
        'destination': destination.id,
        'distanceToDestinationMetres': distToDestination.toStringAsFixed(1),
      });
      state = AsyncData(
        current.copyWith(
          currentLocation: location,
          isNavigating: false,
          hasArrived: true,
        ),
      );
      return;
    }

    final lastFetch = _lastRouteFetchLocation;
    if (lastFetch == null) {
      return;
    }
    final distFromLastFetch = haversineMetres(
      lat1: location.latitude,
      lng1: location.longitude,
      lat2: lastFetch.latitude,
      lng2: lastFetch.longitude,
    );

    var isOffRoute = false;
    if (current.route != null && distFromLastFetch > _offRouteThresholdMetres) {
      final routePoints = resolveRoutePoints(current.route!);
      if (routePoints.isNotEmpty) {
        final closestIdx = findClosestPointIndex(routePoints, location);
        final closestPoint = routePoints[closestIdx];
        final distToRoute = haversineMetres(
          lat1: location.latitude,
          lng1: location.longitude,
          lat2: closestPoint.latitude,
          lng2: closestPoint.longitude,
        );
        if (distToRoute > _offRouteThresholdMetres) {
          isOffRoute = true;
        }
      }
    }

    _logNavigationDiagnostics(
      location: location,
      distFromLastFetch: distFromLastFetch,
      distToDestination: distToDestination,
      isOffRoute: isOffRoute,
      routeDistanceMeters: current.route?.distanceMeters,
    );

    if (isOffRoute) {
      AppLogger.info('Navigation route recalculation triggered', {
        'distFromLastFetchMetres': distFromLastFetch.toStringAsFixed(1),
        'distToDestinationMetres': distToDestination.toStringAsFixed(1),
        'isOffRoute': isOffRoute,
      });
      unawaited(loadRoute());
    }
  }

  void _logNavigationDiagnostics({
    required LocationSample location,
    required double distFromLastFetch,
    required double distToDestination,
    required bool isOffRoute,
    required int? routeDistanceMeters,
  }) {
    final now = DateTime.now();
    final last = _lastNavDiagnosticsAt;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _lastNavDiagnosticsAt = now;
    AppLogger.debug('Navigation diagnostics', {
      'accuracyMetres': location.accuracy?.toStringAsFixed(1),
      'distFromLastFetchMetres': distFromLastFetch.toStringAsFixed(1),
      'distToDestinationMetres': distToDestination.toStringAsFixed(1),
      'isOffRoute': isOffRoute,
      'routeDistanceMeters': routeDistanceMeters,
    });
  }

  int _beginRouteRequest() {
    _routeRequestVersion += 1;
    return _routeRequestVersion;
  }

  void _invalidateRouteRequest() {
    _routeRequestVersion += 1;
  }

  bool _isRouteRequestCurrent(
    int requestId, {
    required String selectedBuildingId,
    required TravelMode travelMode,
  }) {
    final current = state.value;
    return current != null &&
        _routeRequestVersion == requestId &&
        current.selectedBuilding?.id == selectedBuildingId &&
        current.travelMode == travelMode;
  }

  MapStateError _errorForPermission(LocationPermissionState state) {
    return switch (state) {
      LocationPermissionState.servicesDisabled =>
        MapStateError.locationServicesDisabled,
      LocationPermissionState.deniedForever =>
        MapStateError.locationPermissionBlocked,
      LocationPermissionState.denied =>
        MapStateError.locationPermissionRequired,
      LocationPermissionState.unsupported => MapStateError.locationUnsupported,
      LocationPermissionState.granted => MapStateError.locationUnavailable,
    };
  }
}

/// Monotonic counter bumped by flows OUTSIDE the Journey tab that navigate
/// to the Campus Map for a specific target (suggested stops, "show on map"
/// buttons, event direction sheets).
///
/// The Journey page keeps its Campus Map / AR mode as retained state; if the
/// user last used AR, an incoming building selection would otherwise render
/// the AR indoor view instead of the map. Bumping this counter tells the map
/// page "this navigation wants the Campus Map" — without disturbing
/// selections made from inside AR mode itself (which never bump it).
final campusMapIntentProvider =
    NotifierProvider<CampusMapIntentNotifier, int>(CampusMapIntentNotifier.new);

class CampusMapIntentNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Signal that the next map navigation must show the Campus Map view.
  void bump() => state++;
}
