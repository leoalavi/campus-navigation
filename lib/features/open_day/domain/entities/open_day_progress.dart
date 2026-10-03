import 'package:flutter/foundation.dart';
import 'package:campus_navigation/features/open_day/domain/entities/open_day_data.dart';

/// A single entry in the user's saved "Your Day" list.
///
/// Sessions and suggested stops are saved through the same itinerary, so the
/// UI iterates one unified list rather than two parallel ones. Kept a sealed
/// hierarchy so callers `switch` exhaustively with no "unknown type" branch.
sealed class UserDayItem {
  const UserDayItem();

  /// Stable id of the underlying entity (event id or stop id).
  String get id;
}

/// A saved Open Day session (time-bound info session / event).
@immutable
class UserDaySession extends UserDayItem {
  const UserDaySession(this.event);
  final OpenDayEvent event;

  @override
  String get id => event.id;
}

/// A saved suggested stop (a place to visit, not time-bound).
@immutable
class UserDayStop extends UserDayItem {
  const UserDayStop(this.stop);
  final OpenDaySuggestedStop stop;

  @override
  String get id => stop.id;
}

/// Lightweight gamification snapshot for the Open Day "trail".
///
/// Deliberately small: a fraction of featured stops visited, total XP, and a
/// single "trail complete" flag. No levels, no economy — this stays a
/// secondary nudge, never the main experience.
@immutable
class VisitProgress {
  const VisitProgress({
    required this.visitedCount,
    required this.totalCount,
    required this.xp,
    required this.trailComplete,
    this.trailName,
  });

  /// Featured stops visited so far.
  final int visitedCount;

  /// Total featured stops in the current trail.
  final int totalCount;

  /// Total XP earned across all first-time visits.
  final int xp;

  /// True when every featured stop in the trail has been visited.
  final bool trailComplete;

  /// Display name of the trail (e.g. the study-interest name), if any.
  final String? trailName;

  bool get hasTrail => totalCount > 0;

  double get fraction => totalCount == 0 ? 0 : visitedCount / totalCount;

  static const VisitProgress empty = VisitProgress(
    visitedCount: 0,
    totalCount: 0,
    xp: 0,
    trailComplete: false,
  );
}
