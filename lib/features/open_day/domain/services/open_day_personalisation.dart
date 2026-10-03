import 'package:flutter/foundation.dart';
import 'package:mq_navigation/features/open_day/domain/entities/open_day_data.dart';

/// Snapshot of the Open Day schedule relative to a point in time, biased
/// toward the user's selected study interest.
///
/// Computed by [OpenDayPersonalisation.liveStatus]. Held as a value type so
/// the UI can pattern-match on it without re-deriving anything.
@immutable
class OpenDayLiveStatus {
  const OpenDayLiveStatus({
    required this.liveNow,
    required this.comingUpNext,
    required this.usedFallback,
  });

  /// Events currently running (start ≤ now ≤ end).
  final List<OpenDayEvent> liveNow;

  /// The single soonest event that hasn't started yet, or `null` if the day
  /// is over.
  final OpenDayEvent? comingUpNext;

  /// True when there were no interest-relevant events to show and the result
  /// fell back to the full schedule. Lets the UI label the section honestly
  /// ("Across Open Day" vs "For your interest").
  final bool usedFallback;

  bool get isEmpty => liveNow.isEmpty && comingUpNext == null;
}

/// Pure personalisation logic for the Open Day / Home experience.
///
/// **Why this is a standalone service**
///   Every "what should this user see?" decision lives here as a static,
///   side-effect-free function. Widgets and providers call in; nothing in
///   this file imports Flutter UI or Riverpod. That keeps the ranking rules
///   unit-testable in isolation and prevents the logic from being copy-pasted
///   across the Suggested Stops, Your Day and Live Now widgets.
class OpenDayPersonalisation {
  OpenDayPersonalisation._();

  /// Returns the suggested stops most relevant to [selected], ranked
  /// trimmed to [max].
  ///
  /// **Degree-first, NOT faculty-wide.** The selection rule is:
  ///   1. stops that name the exact selected degree in `bachelorIds`;
  ///   2. plus universal stops (Library, Hub, food) that suit any visitor.
  ///
  /// Faculty (study-area) sibling stops are included **only as a fallback**
  /// when the degree has no dedicated stop at all — never by default. This
  /// stops e.g. a Bachelor of Information Technology from being shown the
  /// whole Science & Engineering building list (Physics, Biology, Engineering
  /// …); it sees the School of Computing plus general campus spots.
  static List<OpenDaySuggestedStop> suggestedStops(
    OpenDayData data,
    OpenDayBachelor? selected, {
    int max = 5,
  }) {
    final stops = data.suggestedStops;
    bool isUniversal(OpenDaySuggestedStop s) =>
        s.studyAreaIds.isEmpty && s.bachelorIds.isEmpty;
    final universal = stops.where(isUniversal).toList();

    if (selected == null) {
      // No interest chosen → general campus highlights only.
      return universal.take(max).toList();
    }

    final exact = stops
        .where((s) => s.bachelorIds.contains(selected.id))
        .toList();
    if (exact.isNotEmpty) {
      // Degree-specific stops first, then general — no faculty siblings.
      return [...exact, ...universal].take(max).toList();
    }

    // Fallback ONLY when the degree has no dedicated stop: surface its
    // faculty's stops (study-area match) so the section isn't empty.
    final faculty = stops
        .where(
          (s) =>
              !isUniversal(s) && s.studyAreaIds.contains(selected.studyAreaId),
        )
        .toList();
    return [...faculty, ...universal].take(max).toList();
  }

  /// Computes the live/upcoming snapshot for Home — degree-first.
  ///
  /// [degreeStrict] are sessions that name the exact selected degree (NOT the
  /// whole faculty). [generalFallback] are general/open-to-all sessions.
  /// Degree sessions win; only when none are live/upcoming do we fall back to
  /// general sessions — flagged via [OpenDayLiveStatus.usedFallback] so the UI
  /// can label it honestly ("Open to all visitors"). It never falls back to
  /// unrelated same-faculty sessions.
  static OpenDayLiveStatus liveStatus(
    List<OpenDayEvent> degreeStrict,
    List<OpenDayEvent> generalFallback,
    DateTime now,
  ) {
    final primary = _statusFrom(degreeStrict, now, usedFallback: false);
    if (!primary.isEmpty) return primary;
    return _statusFrom(generalFallback, now, usedFallback: true);
  }

  /// Live/upcoming snapshot scoped to a single location (building code).
  ///
  /// This is the reuse seam for the QR / scanned-location feature: given the
  /// full schedule and a building code, it returns what's on *at that place*
  /// right now and next — using the exact same [OpenDayLiveStatus] shape the
  /// Home cards consume, so a location card can render identically.
  static OpenDayLiveStatus liveStatusForLocation(
    List<OpenDayEvent> all,
    String buildingCode,
    DateTime now,
  ) {
    final code = buildingCode.trim().toUpperCase();
    final atLocation = all
        .where((e) => (e.buildingCode ?? '').trim().toUpperCase() == code)
        .toList();
    return _statusFrom(atLocation, now, usedFallback: false);
  }

  static OpenDayLiveStatus _statusFrom(
    List<OpenDayEvent> events,
    DateTime now, {
    required bool usedFallback,
  }) {
    final sorted = [...events]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final liveNow = <OpenDayEvent>[];
    OpenDayEvent? comingUpNext;
    for (final e in sorted) {
      final isLive = !now.isBefore(e.startTime) && !now.isAfter(e.endTime);
      if (isLive) {
        liveNow.add(e);
      } else if (e.startTime.isAfter(now) && comingUpNext == null) {
        comingUpNext = e;
      }
    }
    return OpenDayLiveStatus(
      liveNow: liveNow,
      comingUpNext: comingUpNext,
      usedFallback: usedFallback,
    );
  }
}
