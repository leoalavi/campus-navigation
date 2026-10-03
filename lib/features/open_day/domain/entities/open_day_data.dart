import 'package:flutter/foundation.dart';

/// Domain models for the Open Day feature.
///
/// The data flow is: `assets/data/open_day.json` → loader → these models →
/// controllers → UI. The schema is intentionally simple so an updated
/// XLSX/CSV can be transformed into the same JSON shape without any Dart
/// changes.
@immutable
class OpenDayStudyArea {
  const OpenDayStudyArea({
    required this.id,
    required this.name,
    required this.icon,
  });

  final String id;
  final String name;

  /// Material icon family name (e.g. `science`, `medical_services`). Kept
  /// as a string so the JSON can stay framework-agnostic.
  final String icon;

  factory OpenDayStudyArea.fromJson(Map<String, dynamic> json) {
    return OpenDayStudyArea(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: (json['icon'] as String?) ?? 'school',
    );
  }
}

@immutable
class OpenDayBachelor {
  const OpenDayBachelor({
    required this.id,
    required this.name,
    required this.studyAreaId,
  });

  final String id;
  final String name;
  final String studyAreaId;

  factory OpenDayBachelor.fromJson(Map<String, dynamic> json) {
    return OpenDayBachelor(
      id: json['id'] as String,
      name: json['name'] as String,
      studyAreaId: json['studyAreaId'] as String,
    );
  }
}

@immutable
class OpenDayEvent {
  const OpenDayEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.venueName,
    required this.bachelorIds,
    this.buildingCode,
    this.description,
    this.repeating = false,
  });

  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String venueName;

  /// Whether the official program marks this as a repeating session (the
  /// "R" flag in the Open Day info-sessions grid).
  final bool repeating;

  /// Optional link into the campus `buildings.json` registry. When present,
  /// the "View in Campus Map" action can route directly to the building
  /// detail page; when absent, the action is hidden gracefully.
  final String? buildingCode;
  final List<String> bachelorIds;
  final String? description;

  /// Returns true if this event is relevant to a given bachelor selection.
  /// An empty `bachelorIds` list is treated as "open to everyone".
  bool isRelevantTo(String? bachelorId) {
    if (bachelorIds.isEmpty) return true;
    if (bachelorId == null) return false;
    return bachelorIds.contains(bachelorId);
  }

  factory OpenDayEvent.fromJson(Map<String, dynamic> json) {
    return OpenDayEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      venueName: json['venueName'] as String,
      buildingCode: json['buildingCode'] as String?,
      description: json['description'] as String?,
      repeating: (json['repeating'] as bool?) ?? false,
      bachelorIds:
          (json['bachelorIds'] as List?)?.cast<String>() ?? const <String>[],
    );
  }
}

/// A featured campus location recommended on the Home screen based on the
/// user's selected study interest.
///
/// Relevance is intentionally data-driven (see `assets/data/open_day.json`):
///   • `bachelorIds`  — strong, discipline-specific match (e.g. the School
///     of Computing for a Computing bachelor).
///   • `studyAreaIds` — faculty-level match (e.g. any FSE stop for any
///     Science & Engineering bachelor).
///   • both empty     — a universal stop (Library, Hub) shown to everyone
///     as a graceful fallback so the list always has enough entries.
@immutable
class OpenDaySuggestedStop {
  const OpenDaySuggestedStop({
    required this.id,
    required this.title,
    required this.description,
    this.buildingCode,
    this.icon = 'place',
    this.studyAreaIds = const <String>[],
    this.bachelorIds = const <String>[],
  });

  final String id;
  final String title;
  final String description;

  /// Optional link into the campus `buildings.json` registry. When present,
  /// tapping the stop can route into the Campus Map; when absent, the stop
  /// is still shown but is not tappable-to-map.
  final String? buildingCode;

  /// Material icon family name, kept as a string so the JSON stays
  /// framework-agnostic (mirrors [OpenDayStudyArea.icon]).
  final String icon;

  final List<String> studyAreaIds;
  final List<String> bachelorIds;

  /// Higher = more specific to this bachelor. Used purely for ranking, so
  /// the exact magnitudes only matter relative to each other:
  ///   3 → matches the bachelor directly
  ///   2 → matches the bachelor's study area
  ///   1 → universal stop (no targeting)
  ///   0 → not relevant to this bachelor
  ///
  /// With no selection, only universal stops score (1) so a brand-new user
  /// still sees sensible campus highlights.
  int relevanceFor(OpenDayBachelor? bachelor) {
    if (bachelor != null && bachelorIds.contains(bachelor.id)) return 3;
    if (bachelor != null && studyAreaIds.contains(bachelor.studyAreaId)) {
      return 2;
    }
    if (studyAreaIds.isEmpty && bachelorIds.isEmpty) return 1;
    return 0;
  }

  factory OpenDaySuggestedStop.fromJson(Map<String, dynamic> json) {
    return OpenDaySuggestedStop(
      id: json['id'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      buildingCode: json['buildingCode'] as String?,
      icon: (json['icon'] as String?) ?? 'place',
      studyAreaIds:
          (json['studyAreaIds'] as List?)?.cast<String>() ?? const <String>[],
      bachelorIds:
          (json['bachelorIds'] as List?)?.cast<String>() ?? const <String>[],
    );
  }
}

/// Top-level Open Day dataset, loaded once and held in memory.
@immutable
class OpenDayData {
  const OpenDayData({
    required this.openDayDate,
    required this.lastUpdated,
    required this.studyAreas,
    required this.bachelors,
    required this.events,
    this.suggestedStops = const <OpenDaySuggestedStop>[],
  });

  final DateTime openDayDate;
  final DateTime lastUpdated;
  final List<OpenDayStudyArea> studyAreas;
  final List<OpenDayBachelor> bachelors;
  final List<OpenDayEvent> events;
  final List<OpenDaySuggestedStop> suggestedStops;

  OpenDayBachelor? bachelorById(String? id) {
    if (id == null) return null;
    for (final b in bachelors) {
      if (b.id == id) return b;
    }
    return null;
  }

  OpenDayStudyArea? studyAreaById(String id) {
    for (final s in studyAreas) {
      if (s.id == id) return s;
    }
    return null;
  }

  factory OpenDayData.fromJson(Map<String, dynamic> json) {
    return OpenDayData(
      openDayDate: DateTime.parse(json['openDayDate'] as String),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      studyAreas: ((json['studyAreas'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(OpenDayStudyArea.fromJson)
          .toList(growable: false),
      bachelors: ((json['bachelors'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(OpenDayBachelor.fromJson)
          .toList(growable: false),
      events: ((json['events'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(OpenDayEvent.fromJson)
          .toList(growable: false),
      suggestedStops: ((json['suggestedStops'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(OpenDaySuggestedStop.fromJson)
          .toList(growable: false),
    );
  }
}
