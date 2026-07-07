/// Public deep-link contract for MQ Journey.
///
/// This file is the **single source of truth** that sister apps (e.g. the
/// Syllabus Sync companion) rely on when generating "Open in MQ Journey"
/// links. Internal GoRouter paths can change freely — the contract below
/// should not.
///
/// Supported payloads, all expressed on the `/open` entry path:
///
///   `/open?destination=<buildingId>`   — focus the map on a known building
///   `/open?q=<search>`                 — filter the map by a free-text query
///   `/open?lat=<double>&lng=<double>`  — drop a "meet here" pin at coords
///
/// The first matching parameter wins, in the order above. Anything else
/// falls back to the map root.
///
/// Example URLs the Syllabus Sync app should construct:
///
///   https://mqnavigation.app/open?destination=E7A
///   mqnav://open?q=library
///   https://mqnavigation.app/open?lat=-33.7738&lng=151.1126
///
/// The matching "Download MQ Journey" fallback (shown when the app is
/// not installed) is the responsibility of Syllabus Sync — universal-link
/// resolution on iOS / app-link resolution on Android will surface the
/// Play Store / App Store listing automatically when the app is absent.
library;

/// Query parameter names. Keep these stable — renaming is a breaking
/// change for any integrating app.
abstract final class MqNavDeepLinkParams {
  static const destination = 'destination';
  static const query = 'q';
  static const latitude = 'lat';
  static const longitude = 'lng';
}

/// Result of parsing a deep-link payload. Used by the router to decide
/// which internal route to forward to.
sealed class MqNavDeepLinkTarget {
  const MqNavDeepLinkTarget();
}

/// Focus the map on a known building by ID.
class DeepLinkBuilding extends MqNavDeepLinkTarget {
  const DeepLinkBuilding(this.buildingId);
  final String buildingId;
}

/// Filter the map by a free-text search query.
class DeepLinkSearch extends MqNavDeepLinkTarget {
  const DeepLinkSearch(this.query);
  final String query;
}

/// Drop a "meet here" pin at a coordinate pair.
class DeepLinkMeetAt extends MqNavDeepLinkTarget {
  const DeepLinkMeetAt({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

/// No resolvable payload — caller should open the map root.
class DeepLinkFallback extends MqNavDeepLinkTarget {
  const DeepLinkFallback();
}

/// Parses the query parameters of an `/open` URL into a target.
///
/// Pure function — safe to unit-test. See [MqNavDeepLinkParams] for the
/// parameter names this recognises.
MqNavDeepLinkTarget parseMqNavDeepLink(Map<String, String> params) {
  final destination = params[MqNavDeepLinkParams.destination]?.trim();
  if (destination != null && destination.isNotEmpty) {
    return DeepLinkBuilding(destination);
  }
  final query = params[MqNavDeepLinkParams.query]?.trim();
  if (query != null && query.isNotEmpty) {
    return DeepLinkSearch(query);
  }
  final lat = double.tryParse(params[MqNavDeepLinkParams.latitude] ?? '');
  final lng = double.tryParse(params[MqNavDeepLinkParams.longitude] ?? '');
  if (lat != null && lng != null) {
    return DeepLinkMeetAt(latitude: lat, longitude: lng);
  }
  return const DeepLinkFallback();
}
