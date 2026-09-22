/// Public deep-link contract for Campus Navigation.
///
/// The app's display name changed from "MQ Navigation" to "Campus
/// Navigation", but this contract did NOT: the `mqnavigation.app` domain,
/// the `/open` path and every parameter name below are unchanged, so links
/// already emitted by companion apps keep resolving.
///
/// This file is the **single source of truth** that sister apps (e.g. the
/// Syllabus Sync companion) rely on when generating "Open in Campus Navigation"
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
/// The matching "Download Campus Navigation" fallback (shown when the app is
/// not installed) is the responsibility of Syllabus Sync. It must present an
/// explicit App Store / Google Play chooser: Campus Navigation is an Android +
/// iOS product with NO web build, so there is nothing to fall back to in a
/// browser.
///
/// ## Transport
///
/// Two transports carry the same `/open` payload:
///
///   * `mqnav://open?...` — the custom scheme. Always available once the app
///     is installed, needs no domain verification, and is the reliable primary
///     handoff. `io.mqnavigation://` remains registered for the pre-existing
///     auth/meet links and is NOT part of this public contract.
///   * `https://mqnavigation.app/open?...` — App Links / Universal Links.
///     Nicer when it works, but only after the domain serves
///     `/.well-known/assetlinks.json` and `/.well-known/apple-app-site-
///     association`. Treat as an enhancement, never the only path.
///
/// The former `io.mqnavigation://callback` and `https://mqnavigation.io/auth`
/// links were removed together with the authentication feature — Campus
/// Navigation has no accounts. `io.mqnavigation://meet` is retained because
/// "meet here" links to it are already in circulation.
library;

/// Query parameter names. Keep these stable — renaming is a breaking
/// change for any integrating app.
abstract final class MqNavDeepLinkParams {
  static const destination = 'destination';
  static const query = 'q';
  static const latitude = 'lat';
  static const longitude = 'lng';
}

/// Transport constants. Sister apps build links from these; the app registers
/// the matching intent filters / URL types natively.
abstract final class MqNavDeepLink {
  /// Custom scheme — the dependable handoff, no domain setup required.
  static const scheme = 'mqnav';

  /// Verified-link domain. Requires well-known files to be served before it
  /// resolves to the app rather than a browser.
  static const host = 'mqnavigation.app';

  /// The single public entry path. Internal routes may move; this may not.
  static const path = '/open';

  /// Legacy custom scheme kept for the pre-existing auth + "meet here" links.
  static const legacyScheme = 'io.mqnavigation';

  /// Whether [uri] is addressed to this app's public entry point, over either
  /// transport. Anything else must be ignored so unrelated links (Supabase
  /// auth callbacks, OS-generated URLs) are not mistaken for navigation.
  static bool isOpenLink(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (uri.scheme == scheme) {
      // `mqnav://open?x=1` parses with host 'open' and an empty path.
      return uri.host == 'open' || path == MqNavDeepLink.path;
    }
    if (uri.scheme == 'https' && uri.host == host) {
      return path == MqNavDeepLink.path;
    }
    return false;
  }
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

/// Builds the canonical `/open` link for a building.
///
/// Exposed so the app itself (Share, "copy link") emits exactly the shape it
/// documents, rather than a hand-assembled string that could drift from the
/// contract sister apps implement.
Uri buildCampusNavBuildingLink(String buildingId, {bool https = false}) {
  final query = {MqNavDeepLinkParams.destination: buildingId};
  return https
      ? Uri.https(MqNavDeepLink.host, MqNavDeepLink.path, query)
      : Uri(scheme: MqNavDeepLink.scheme, host: 'open', queryParameters: query);
}
