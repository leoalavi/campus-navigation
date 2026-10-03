import 'package:mq_navigation/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_navigation/features/open_day/domain/entities/open_day_progress.dart';

/// Pure, secondary gamification logic for Open Day.
///
/// **Scope (intentionally tiny):**
///   • Each *first* visit to a location awards a flat [xpPerVisit].
///   • Re-scanning the same location awards nothing (callers dedupe by
///     building code before this ever runs — see
///     `SettingsController.recordLocationVisit`).
///   • Progress is "visited X of N featured stops" for the current trail,
///     plus a single "trail complete" flag.
///
/// No levels, no streaks, no economy. The QR/location feature simply records
/// visits; everything visible is derived here so the rules live in one place.
class OpenDayGamification {
  OpenDayGamification._();

  /// XP granted per unique location visited.
  static const int xpPerVisit = 50;

  static int xpForVisitCount(int uniqueVisits) => uniqueVisits * xpPerVisit;

  /// Computes the progress snapshot.
  ///
  /// [visited] is the set of building codes the user has visited (any case);
  /// [trail] is the featured stop list that defines "the trail" (typically
  /// the suggested stops for the selected interest). [trailName] is shown in
  /// the "Completed X trail" copy.
  static VisitProgress progress({
    required Iterable<String> visited,
    required List<OpenDaySuggestedStop> trail,
    String? trailName,
  }) {
    final visitedUpper = {for (final c in visited) c.trim().toUpperCase()}
      ..removeWhere((c) => c.isEmpty);

    final trailCodes = <String>{
      for (final s in trail)
        if (s.buildingCode != null && s.buildingCode!.trim().isNotEmpty)
          s.buildingCode!.trim().toUpperCase(),
    };

    final visitedInTrail = trailCodes.where(visitedUpper.contains).length;

    return VisitProgress(
      visitedCount: visitedInTrail,
      totalCount: trailCodes.length,
      xp: xpForVisitCount(visitedUpper.length),
      trailComplete:
          trailCodes.isNotEmpty && visitedInTrail == trailCodes.length,
      trailName: trailName,
    );
  }
}
