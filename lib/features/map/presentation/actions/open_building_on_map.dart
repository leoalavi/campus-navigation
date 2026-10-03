import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_navigation/app/router/route_names.dart';
import 'package:campus_navigation/features/map/data/datasources/building_registry_source.dart';
import 'package:campus_navigation/features/map/domain/entities/building.dart';
import 'package:campus_navigation/features/map/domain/entities/map_renderer_type.dart';
import 'package:campus_navigation/features/map/presentation/controllers/map_controller.dart';

/// How a caller wants the Campus Map to enter the navigation stack.
///
/// The side effects in [openBuildingOnCampusMap] are always identical; only
/// the *routing verb* differs, and it differs for a structural reason: `/map`
/// lives inside the `StatefulShellRoute`, while some callers (the scanned-QR
/// venue card at `/location/:id`) live in top-level routes outside it.
enum MapOpenPolicy {
  /// `go` — replace the current location and surface the Navigation tab.
  ///
  /// Correct when the caller is already inside the shell (Home's suggested
  /// stops) or is conceptually *moving* the user to the map rather than
  /// showing it as a detour. The bottom nav remains the way back.
  replaceInShell,

  /// `push` — stack the map on top of the caller, which stays alive beneath.
  ///
  /// Correct for detours that must return exactly where they came from: the
  /// QR venue card pushes the map, the user pops back, and the card's
  /// Added-to-Your-Day / Visited state is still there because the page was
  /// never disposed. Gives real routes to Android back and browser back too.
  push,
}

/// The single way to open a building on the Campus Map.
///
/// Every entry point — Your Day, a saved session, a suggested stop, an Open
/// Day venue, a scanned QR location card — needs the same things to happen
/// together, and each one used to open-code them:
///
/// 1. force the illustrated Campus Map renderer, so an Open Day destination
///    always lands on the campus view with its entrance pin;
/// 2. re-emit the selection imperatively, because navigating to a
///    `/map?building=X` URL the user already visited is a go_router no-op —
///    the kept-alive MapPage is not rebuilt and its param handler never
///    re-runs, so the marker would not re-show;
/// 3. route the navigation according to [policy], keeping the URL in sync so
///    a refresh or deep link lands in the same place.
///
/// Keeping them apart meant flows drifted: the QR location card bumped the
/// intent and navigated but never re-emitted the selection, so returning to a
/// venue you had already opened showed the map with no marker and no detail
/// panel. Routing every caller through here makes the behaviour identical, and
/// it is entirely id-based — no localised label is ever used to identify a
/// destination, so it behaves the same in every locale and text direction.
void openBuildingOnCampusMap(
  BuildContext context,
  String buildingIdOrCode, {
  MapOpenPolicy policy = MapOpenPolicy.replaceInShell,
}) {
  final container = ProviderScope.containerOf(context, listen: false);

  // Prefer the registry's canonical id when it is already loaded; the raw
  // code is a valid fallback because the controller matches on either. Read
  // without awaiting: this is a navigation action, not a data load, and the
  // map resolves the code itself.
  final registry = container.read(buildingRegistryProvider).value;
  final targetId = _resolve(registry, buildingIdOrCode)?.id ?? buildingIdOrCode;

  final controller = container.read(mapControllerProvider.notifier);
  controller.setRenderer(MapRendererType.campus);
  controller.selectBuildingById(targetId);

  switch (policy) {
    case MapOpenPolicy.replaceInShell:
      context.goNamed(RouteNames.map, queryParameters: {'building': targetId});
    case MapOpenPolicy.push:
      context.pushNamed(
        RouteNames.map,
        queryParameters: {'building': targetId},
      );
  }
}

Building? _resolve(List<Building>? buildings, String code) {
  if (buildings == null) return null;
  final upper = code.toUpperCase();
  for (final b in buildings) {
    if (b.code.toUpperCase() == upper || b.id.toUpperCase() == upper) return b;
  }
  return null;
}
