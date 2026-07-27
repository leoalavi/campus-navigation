import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/data/datasources/building_registry_source.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/presentation/actions/open_building_on_map.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/shared/async/bounded_provider_read.dart';

/// How long to wait for the building registry before giving up on it.
///
/// The registry reads a bundled asset, so it normally resolves in
/// milliseconds; three seconds is already far past "something is wrong".
/// Timing out early is cheap because the fallback below routes to the very
/// same building via the event's own code — the only thing lost is the
/// registry's canonical id.
///
/// This bound is load-bearing, not belt-and-braces. Verified against the
/// vendored Riverpod: a `FutureProvider` whose create function throws never
/// transitions to `AsyncError` — it stays `AsyncLoading` forever, and
/// `provider.future` never settles. Without a timeout a failing registry left
/// this await pending for the life of the app and the venue button did
/// nothing at all, with no error anywhere.
const Duration kVenueLookupTimeout = Duration(seconds: 3);

/// Takes the user straight to [event]'s venue on the Campus Map.
///
/// This used to raise a bottom sheet whose only action was "View in Campus
/// Map". With a single campus map there is nothing to choose between, so the
/// sheet was pure friction — one extra tap between the user and the map.
///
/// The button always resolves to something the user can see: it navigates, or
/// it explains why it can't and offers a retry. It never sits silent.
Future<void> openEventVenueOnMap(
  BuildContext context,
  OpenDayEvent event,
) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;

  final code = event.buildingCode;
  // No building code at all is a property of the event, not a transient
  // failure — retrying can never change it, so say so plainly and stop.
  if (code == null || code.trim().isEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.openDay_noMappableVenue)),
    );
    return;
  }

  final buildings = await readProviderBounded(
    container,
    buildingRegistryProvider,
    timeout: kVenueLookupTimeout,
  );
  // Null means the registry could not answer — a thrown error or a timeout.
  // Either way it is a *transient* condition, unlike "answered, no match".
  final registryUnavailable = buildings == null;
  final resolved = _resolveBuilding(buildings, code);
  if (!context.mounted) return;

  if (resolved != null) {
    openBuildingOnCampusMap(context, resolved.id);
    return;
  }

  if (!registryUnavailable) {
    // The registry answered and simply has no such building. Retrying would
    // ask the same question and get the same answer.
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.openDay_noMappableVenue)),
    );
    return;
  }

  // Registry unavailable — fall back to the code the event itself carries.
  // This is the event's own curated data (an asset test asserts every event
  // code resolves in the registry), never a default or nearby location, and
  // the map controller matches on code as well as id. Only use it when the
  // map can actually place it, so a fallback can never dump the user on a
  // blank campus map with no pin.
  if (_mapCanPlace(container, code)) {
    openBuildingOnCampusMap(context, code);
    return;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.openDay_venueLookupFailed),
      action: SnackBarAction(
        label: l10n.retry,
        onPressed: () {
          // Drop the failed/timed-out result so the retry re-reads the
          // registry instead of awaiting the same dead future again.
          container.invalidate(buildingRegistryProvider);
          if (context.mounted) openEventVenueOnMap(context, event);
        },
      ),
    ),
  );
}

/// Whether the map already holds a building matching [code], so a fallback
/// navigation will actually land on a pin.
bool _mapCanPlace(ProviderContainer container, String code) {
  final buildings = container.read(mapControllerProvider).value?.buildings;
  if (buildings == null) return false;
  return _resolveBuilding(buildings, code) != null;
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
