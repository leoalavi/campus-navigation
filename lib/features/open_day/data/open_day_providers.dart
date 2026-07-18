import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_progress.dart';
import 'package:mq_journey/features/open_day/domain/services/open_day_gamification.dart';
import 'package:mq_journey/features/open_day/domain/services/open_day_personalisation.dart';
import 'package:mq_journey/features/scan/providers/trail_providers.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';

/// Bundles the Open Day dataset asset path so it can be overridden in
/// tests without reaching into the loader implementation.
const _openDayAssetPath = 'assets/data/open_day.json';

/// Loads `assets/data/open_day.json` once per app session. The result is
/// cached by Riverpod so subsequent watchers don't re-parse the JSON.
///
/// Errors are surfaced via the standard `AsyncValue.error` channel so the
/// Open Day page can show a friendly retry state instead of crashing.
final openDayDataProvider = FutureProvider<OpenDayData>((ref) async {
  final raw = await rootBundle.loadString(_openDayAssetPath);
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return OpenDayData.fromJson(json);
});

/// Convenience: the currently selected bachelor object (or `null`).
///
/// Reads from settings + open-day data and joins them. Returning the
/// resolved `OpenDayBachelor` rather than just the id keeps every UI
/// consumer free of "look up the id again" boilerplate.
final selectedBachelorProvider = Provider<OpenDayBachelor?>((ref) {
  final selectedId = ref
      .watch(settingsControllerProvider)
      .value
      ?.selectedBachelorId;
  final data = ref.watch(openDayDataProvider).value;
  if (selectedId == null || data == null) return null;
  return data.bachelorById(selectedId);
});

/// Events relevant to the user's selected bachelor, sorted by start time.
///
/// When no bachelor is selected, returns events with empty `bachelorIds`
/// (treated as open to everyone) — keeps the page useful during onboarding.
final relevantOpenDayEventsProvider = Provider<List<OpenDayEvent>>((ref) {
  final data = ref.watch(openDayDataProvider).value;
  if (data == null) return const [];
  final selectedId = ref
      .watch(settingsControllerProvider)
      .value
      ?.selectedBachelorId;
  final filtered = data.events.where((e) => e.isRelevantTo(selectedId)).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  return filtered;
});

/// Sessions that name the **exact** selected degree (NOT the whole faculty),
/// sorted by start time. Empty when no interest is chosen. This is the
/// "Matched to your degree" feed.
final degreeSessionsProvider = Provider<List<OpenDayEvent>>((ref) {
  final data = ref.watch(openDayDataProvider).value;
  if (data == null) return const [];
  final selectedId = ref
      .watch(settingsControllerProvider)
      .value
      ?.selectedBachelorId;
  if (selectedId == null) return const [];
  final list =
      data.events.where((e) => e.bachelorIds.contains(selectedId)).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
  return list;
});

/// General / open-to-all sessions (empty `bachelorIds`), sorted by start time.
/// These are intentionally open to every visitor (pathways, HSC tips, etc.)
/// and are shown in their own clearly-labelled section — never mixed into the
/// degree feed.
final generalSessionsProvider = Provider<List<OpenDayEvent>>((ref) {
  final data = ref.watch(openDayDataProvider).value;
  if (data == null) return const [];
  final list = data.events.where((e) => e.bachelorIds.isEmpty).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  return list;
});

/// Suggested campus stops ranked for the user's selected interest.
///
/// Delegates ranking to [OpenDayPersonalisation.suggestedStops] so the UI
/// never re-implements relevance scoring. Returns an empty list until the
/// dataset has loaded.
final suggestedStopsProvider = Provider<List<OpenDaySuggestedStop>>((ref) {
  final data = ref.watch(openDayDataProvider).value;
  if (data == null) return const [];
  final selected = ref.watch(selectedBachelorProvider);
  return OpenDayPersonalisation.suggestedStops(data, selected);
});

/// Injectable clock so the Live Now / Coming Up Next logic is deterministic
/// in tests. Production reads `DateTime.now()`; tests override this provider.
final openDayNowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Live / upcoming snapshot for Home — degree-first.
///
/// Primary = sessions that name the exact selected degree (NOT the whole
/// faculty). Fallback = general/open-to-all sessions only. It never surfaces
/// unrelated same-faculty sessions, so "Coming Up Next" for Bachelor of IT
/// shows the next IT session (or, failing that, an honestly-labelled general
/// session) — not the next Engineering/Science session.
final openDayLiveStatusProvider = Provider<OpenDayLiveStatus>((ref) {
  final now = ref.watch(openDayNowProvider);
  final degreeStrict = ref.watch(degreeSessionsProvider);
  final general = ref.watch(generalSessionsProvider);
  return OpenDayPersonalisation.liveStatus(degreeStrict, general, now);
});

/// The user's saved "Your Day" events, resolved from stored IDs to full
/// event objects and sorted by start time. Silently drops IDs that no longer
/// exist in the dataset (e.g. after a schedule update).
final savedOpenDayEventsProvider = Provider<List<OpenDayEvent>>((ref) {
  final data = ref.watch(openDayDataProvider).value;
  if (data == null) return const [];
  final savedIds =
      ref.watch(settingsControllerProvider).value?.savedOpenDayEventIds ??
      const <String>[];
  if (savedIds.isEmpty) return const [];
  final byId = {for (final e in data.events) e.id: e};
  final resolved = [
    for (final id in savedIds)
      if (byId[id] != null) byId[id]!,
  ]..sort((a, b) => a.startTime.compareTo(b.startTime));
  return resolved;
});

/// The unified "Your Day" itinerary: saved sessions first (chronological,
/// the natural backbone of the day) followed by saved stops (places to drop
/// into between sessions). One list so the UI never juggles two collections.
final userDayItemsProvider = Provider<List<UserDayItem>>((ref) {
  final data = ref.watch(openDayDataProvider).value;
  if (data == null) return const [];
  final prefs = ref.watch(settingsControllerProvider).value;
  final sessions = ref.watch(savedOpenDayEventsProvider);

  final savedStopIds = prefs?.savedStopIds ?? const <String>[];
  final stopById = {for (final s in data.suggestedStops) s.id: s};

  // Scanned QR venues save their trail locationId (e.g. "wallys-29") into the
  // SAME savedStopIds list. Those ids aren't Open Day suggested stops, so
  // resolve any leftover ids against the scanned trail so they still render
  // in Your Day (and count on the Home card) instead of vanishing silently.
  final trail = ref.watch(trailManifestProvider).value;
  final trailById = {
    if (trail != null)
      for (final loc in trail.locations) loc.locationId: loc,
  };

  final stops = <OpenDaySuggestedStop>[];
  for (final id in savedStopIds) {
    final stop = stopById[id];
    if (stop != null) {
      stops.add(stop);
      continue;
    }
    final loc = trailById[id];
    if (loc != null) {
      stops.add(
        OpenDaySuggestedStop(
          id: loc.locationId,
          title: loc.title,
          description: loc.description ?? '',
          buildingCode: loc.mapBuildingCode ?? loc.buildingId,
        ),
      );
    }
  }

  return <UserDayItem>[
    for (final e in sessions) UserDaySession(e),
    for (final s in stops) UserDayStop(s),
  ];
});

/// Live/upcoming snapshot for a specific building code — the reuse seam for
/// the future QR / scanned-location cards. Reads the injected clock so it
/// stays testable and consistent with the Home-level Live Now.
final locationLiveStatusProvider = Provider.family<OpenDayLiveStatus, String>((
  ref,
  buildingCode,
) {
  final data = ref.watch(openDayDataProvider).value;
  final now = ref.watch(openDayNowProvider);
  final all = data?.events ?? const <OpenDayEvent>[];
  return OpenDayPersonalisation.liveStatusForLocation(all, buildingCode, now);
});

/// Lightweight gamification progress for the current interest's "trail".
/// Featured stops = the suggested stops for the selected interest, so
/// "Visited X of N" tracks the same places shown on Home.
final visitProgressProvider = Provider<VisitProgress>((ref) {
  final visited =
      ref.watch(settingsControllerProvider).value?.visitedLocationCodes ??
      const <String>[];
  final trail = ref.watch(suggestedStopsProvider);
  final interest = ref.watch(selectedBachelorProvider);
  return OpenDayGamification.progress(
    visited: visited,
    trail: trail,
    trailName: interest?.name,
  );
});
