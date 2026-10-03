import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mq_navigation/features/map/domain/entities/route_leg.dart';

enum LocationPermissionState {
  granted,
  denied,
  deniedForever,
  servicesDisabled,
  unsupported,
}

/// Native location service wrapper powered by `geolocator`.
///
/// Handles Android/iOS permission flows, current position retrieval, and
/// live coordinate streaming during active navigation.
///
/// **No silent fallbacks.** Earlier versions of this file returned a
/// hardcoded "18 Wally's Walk" `LocationSample` whenever the real GPS
/// failed (web, desktop, or unsupported platforms). That secretly told
/// every consumer the user was standing on campus when they weren't —
/// `centerOnLocation` would teleport them to Wally's Walk, route fits
/// would expand to contain the imaginary fix, and the UI would never
/// surface the honest "location unavailable" state. Every method now
/// returns `null` / `unsupported` instead so the controller can show
/// the correct banner.
class LocationSource {
  const LocationSource();
  static const double _googleplexLatitude = 37.4219983;
  static const double _googleplexLongitude = -122.084;
  static const double _googleplexTolerance = 0.0025;

  // We explicitly disable native location services on platforms where the
  // geolocator plugin cannot bind to a real native location service (Web,
  // Linux, Windows). macOS IS supported: the geolocator package ships a
  // CoreLocation-backed plugin, and the macOS Runner already declares
  // both the `NSLocationWhenInUseUsageDescription` Info.plist key AND the
  // `com.apple.security.personal-information.location` entitlement in
  // both DebugProfile.entitlements and Release.entitlements. The only
  // thing blocking macOS until now was this `_isSupported` check
  // excluding it.
  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<LocationPermissionState> ensurePermission() async {
    if (!_isSupported) {
      // On web/desktop there is no platform location service to ask.
      // Report `unsupported` so the controller can show the appropriate
      // banner — we no longer pretend permission is granted just to keep
      // a synthetic fallback alive.
      return LocationPermissionState.unsupported;
    }

    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      return LocationPermissionState.servicesDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionState.deniedForever;
    }
    if (permission == LocationPermission.denied) {
      return LocationPermissionState.denied;
    }

    return LocationPermissionState.granted;
  }

  Future<LocationSample?> getCurrentLocation() async {
    if (!_isSupported) {
      // No real GPS available — return null so the controller surfaces
      // the "location unavailable" banner instead of falsely centering
      // the map on the campus.
      debugPrint(
        'LocationSource: platform unsupported, no GPS — returning null',
      );
      return null;
    }

    final permission = await ensurePermission();
    if (permission != LocationPermissionState.granted) {
      return null;
    }

    // Platform-specific settings give a substantially more accurate fix on
    // Android: `forceLocationManager: true` bypasses the Play-Services Fused
    // Location Provider (which often returns Wi-Fi-triangulated estimates
    // that can be hundreds of metres off the true position) and uses the raw
    // OS LocationManager + GPS provider directly.
    final LocationSettings locationSettings =
        defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 15),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            activityType: ActivityType.fitness,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: false,
          );

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      ).timeout(const Duration(seconds: 15));
      if (_isLikelyEmulatorDefaultMock(position)) {
        debugPrint(
          'LocationSource: ignoring emulator default mock location '
          '(${position.latitude}, ${position.longitude})',
        );
        return null;
      }
      return LocationSample(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (e) {
      // Fresh fix failed (slow GPS lock, emulator without mock provider,
      // indoors with weak signal). Try the OS's last-known fix — for a
      // real device this is the user's actual most-recent location, not
      // a synthetic campus fallback. Only as a last resort do we return
      // null so the controller can show the "location unavailable" banner
      // instead of silently teleporting the user to the campus centre.
      debugPrint('LocationSource: fresh fix failed ($e), trying last known');
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          if (_isLikelyEmulatorDefaultMock(lastKnown)) {
            debugPrint(
              'LocationSource: ignoring last-known emulator default mock '
              'location (${lastKnown.latitude}, ${lastKnown.longitude})',
            );
            return null;
          }
          return LocationSample(
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
            accuracy: lastKnown.accuracy,
            timestamp: lastKnown.timestamp,
          );
        }
      } catch (e2) {
        debugPrint('LocationSource: last-known lookup failed ($e2)');
      }
      return null;
    }
  }

  bool _isLikelyEmulatorDefaultMock(Position position) {
    if (!position.isMocked) {
      return false;
    }
    final latDelta = (position.latitude - _googleplexLatitude).abs();
    final lngDelta = (position.longitude - _googleplexLongitude).abs();
    return latDelta <= _googleplexTolerance && lngDelta <= _googleplexTolerance;
  }

  Stream<LocationSample> watch() async* {
    if (!_isSupported) {
      // Web / desktop: no real-time location updates available.
      return;
    }

    final permission = await ensurePermission();
    if (permission != LocationPermissionState.granted) {
      return;
    }

    // Same platform-specific tuning as `getCurrentLocation` — raw GPS on
    // Android avoids Wi-Fi-triangulation jitter that can pull the
    // navigation dot tens of metres off the route polyline.
    final LocationSettings locationSettings =
        defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
            forceLocationManager: true,
            intervalDuration: const Duration(seconds: 2),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
            activityType: ActivityType.fitness,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: false,
          );

    yield* Geolocator.getPositionStream(locationSettings: locationSettings).map(
      (position) => LocationSample(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      ),
    );
  }

  Future<void> openLocationSettings() async {
    if (!_isSupported) return;
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    if (!_isSupported) return;
    await Geolocator.openAppSettings();
  }
}

final locationSourceProvider = Provider<LocationSource>((ref) {
  return const LocationSource();
});
