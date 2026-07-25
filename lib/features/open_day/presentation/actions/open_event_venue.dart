import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/map/data/datasources/building_registry_source.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';

/// Takes the user straight to [event]'s venue on the Campus Map.
///
/// This used to raise a bottom sheet whose only action was "View in Campus
/// Map". With a single campus map there is nothing to choose between, so the
/// sheet was pure friction — one extra tap between the user and the map. The
/// venue is now opened directly, and the only case that still needs to say
/// anything is a venue with no map location.
Future<void> openEventVenueOnMap(
  BuildContext context,
  OpenDayEvent event,
) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;

  Building? resolvedBuilding;
  if (event.buildingCode != null) {
    try {
      final buildings = await container.read(buildingRegistryProvider.future);
      resolvedBuilding = _resolveBuilding(buildings, event.buildingCode);
    } catch (_) {
      // Registry unavailable — fall through to the "no map location" message
      // rather than navigating to a map that cannot place this venue.
    }
  }
  if (!context.mounted) return;

  if (event.buildingCode == null || resolvedBuilding == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.openDay_noMappableVenue)),
    );
    return;
  }

  final targetBuildingId = resolvedBuilding.id;

  // Re-emit the selection imperatively so the marker re-shows even when the
  // same building URL was opened before (go_router same-URL no-op). Always
  // land on the Campus Map, never a remembered AR view.
  container.read(campusMapIntentProvider.notifier).bump();
  container
      .read(mapControllerProvider.notifier)
      .selectBuildingById(targetBuildingId);
  context.goNamed(
    RouteNames.map,
    queryParameters: {'building': targetBuildingId},
  );
}

Building? _resolveBuilding(List<Building>? buildings, String? code) {
  if (buildings == null || code == null) return null;
  final upper = code.toUpperCase();
  for (final b in buildings) {
    if (b.code.toUpperCase() == upper || b.id.toUpperCase() == upper) {
      return b;
    }
  }
  return null;
}
