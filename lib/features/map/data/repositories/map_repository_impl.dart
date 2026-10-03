import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/features/map/data/datasources/building_registry_source.dart';
import 'package:mq_navigation/features/map/data/datasources/campus_routes_remote_source.dart';
import 'package:mq_navigation/features/map/data/datasources/location_source.dart';
import 'package:mq_navigation/features/map/domain/entities/building.dart';
import 'package:mq_navigation/features/map/domain/entities/route_leg.dart';

abstract interface class MapRepository {
  Future<List<Building>> getBuildings({bool forceRefresh = false});
  Future<LocationPermissionState> ensureLocationPermission();
  Future<LocationSample?> getCurrentLocation();
  Stream<LocationSample> watchLocation();
  Future<MapRoute> getRoute({
    required LocationSample origin,
    required Building destination,
    required TravelMode travelMode,
  });
  Future<void> openLocationSettings();
  Future<void> openAppSettings();
}

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return MapRepositoryImpl(
    buildingRegistrySource: ref.watch(buildingRegistrySourceProvider),
    campusRoutesRemoteSource: ref.watch(campusRoutesRemoteSourceProvider),
    locationSource: ref.watch(locationSourceProvider),
  );
});

class MapRepositoryImpl implements MapRepository {
  const MapRepositoryImpl({
    required BuildingRegistrySource buildingRegistrySource,
    required CampusRoutesRemoteSource campusRoutesRemoteSource,
    required LocationSource locationSource,
  }) : _buildingRegistrySource = buildingRegistrySource,
       _campusRoutesRemoteSource = campusRoutesRemoteSource,
       _locationSource = locationSource;

  final BuildingRegistrySource _buildingRegistrySource;
  final CampusRoutesRemoteSource _campusRoutesRemoteSource;
  final LocationSource _locationSource;

  @override
  Future<List<Building>> getBuildings({bool forceRefresh = false}) {
    return _buildingRegistrySource.getBuildings(forceRefresh: forceRefresh);
  }

  @override
  Future<LocationPermissionState> ensureLocationPermission() {
    return _locationSource.ensurePermission();
  }

  @override
  Future<LocationSample?> getCurrentLocation() {
    return _locationSource.getCurrentLocation();
  }

  @override
  Stream<LocationSample> watchLocation() {
    return _locationSource.watch();
  }

  @override
  Future<MapRoute> getRoute({
    required LocationSample origin,
    required Building destination,
    required TravelMode travelMode,
  }) {
    return _campusRoutesRemoteSource.getRoute(
      origin: origin,
      destination: destination,
      travelMode: travelMode,
    );
  }

  @override
  Future<void> openLocationSettings() {
    return _locationSource.openLocationSettings();
  }

  @override
  Future<void> openAppSettings() {
    return _locationSource.openAppSettings();
  }
}
