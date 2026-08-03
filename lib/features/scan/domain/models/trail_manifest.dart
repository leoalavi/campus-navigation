import 'dart:convert';
import 'package:flutter/foundation.dart';

@immutable
class OpenDayStop {
  final String stopId;
  final String title;
  final String arSceneId;
  final String? scheduleLocationId;

  const OpenDayStop({
    required this.stopId,
    required this.title,
    required this.arSceneId,
    this.scheduleLocationId,
  });
}

@immutable
class TrailLocation {
  final String locationId;
  final String?
  buildingId; // stable address slug, e.g. "wallys-23" — NOT a map grid ref
  final String?
  mapBuildingCode; // campus-map building code with real coords, e.g. "29WW"
  final String title;
  final String? description; // short 2-3 sentence blurb shown on the card
  final List<String> photos;
  final String? arSceneId; // this location's own entrance scene (a node id)

  /// Extra campus-map building codes that resolve to *this* location's indoor
  /// manifest, mapped to the scene each one should open on.
  ///
  /// `mapBuildingCode` is 1:1, but a single physical building can carry more
  /// than one pin on the campus map. Price Theatre is its own building in
  /// `buildings.json` (code `PRICE`) yet lives inside 23 Wally's Walk, whose
  /// manifest already ships a `price` panorama. Without an alias, selecting
  /// Price Theatre on the map and switching to AR looked up a manifest named
  /// `PRICE`, found nothing, and reported "no indoor preview" for a location
  /// the map had just shown. Keyed by stable code → scene id, never by
  /// display title, so it is locale-independent.
  final Map<String, String> arAliases;
  final List<OpenDayStop> stops;

  const TrailLocation({
    required this.locationId,
    this.buildingId,
    this.mapBuildingCode,
    required this.title,
    this.description,
    this.photos = const [],
    this.arSceneId,
    this.arAliases = const {},
    this.stops = const [],
  });
}

@immutable
class TrailManifest {
  final List<TrailLocation> locations;

  const TrailManifest({required this.locations});

  bool contains(String locationId) =>
      locations.any((l) => l.locationId == locationId);

  TrailLocation? byId(String locationId) {
    for (final l in locations) {
      if (l.locationId == locationId) return l;
    }
    return null;
  }

  /// Looks up a location by its campus-map building code (e.g. "14SCO"),
  /// case-insensitively. Indoor manifest assets are named after the trail's
  /// stable `buildingId` slug (e.g. "ondaatje-14"), which differs from the
  /// map registry code — callers that only have the map code (from
  /// `BuildingsRegistry`/`Building.code`) must resolve through this before
  /// loading a manifest.
  TrailLocation? byMapBuildingCode(String mapBuildingCode) {
    final upper = mapBuildingCode.toUpperCase();
    for (final l in locations) {
      if (l.mapBuildingCode?.toUpperCase() == upper) return l;
    }
    // Fall back to explicit aliases: a second map pin inside the same
    // physical building (e.g. PRICE inside 23 Wally's Walk).
    for (final l in locations) {
      for (final alias in l.arAliases.keys) {
        if (alias.toUpperCase() == upper) return l;
      }
    }
    return null;
  }

  /// The scene an aliased campus-map code should open on, if any.
  ///
  /// Returns null for a location's primary code, which opens on its own
  /// entrance scene as before.
  String? arSceneForMapBuildingCode(String mapBuildingCode) {
    final upper = mapBuildingCode.toUpperCase();
    for (final l in locations) {
      if (l.mapBuildingCode?.toUpperCase() == upper) return null;
      for (final entry in l.arAliases.entries) {
        if (entry.key.toUpperCase() == upper) return entry.value;
      }
    }
    return null;
  }

  factory TrailManifest.fromJson(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final locs = (json['locations'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          return TrailLocation(
            locationId: m['locationId'] as String,
            buildingId: m['buildingId'] as String?,
            mapBuildingCode: m['mapBuildingCode'] as String?,
            title: m['title'] as String,
            description: m['description'] as String?,
            photos: ((m['photos'] as List?) ?? const [])
                .map((p) => p as String)
                .toList(growable: false),
            arSceneId: m['arSceneId'] as String?,
            arAliases: ((m['arAliases'] as Map?) ?? const {}).map(
              (k, v) => MapEntry(k as String, v as String),
            ),
            stops: ((m['stops'] as List?) ?? const [])
                .map((s) {
                  final sm = s as Map<String, dynamic>;
                  return OpenDayStop(
                    stopId: sm['stopId'] as String,
                    title: sm['title'] as String,
                    arSceneId: sm['arSceneId'] as String,
                    scheduleLocationId: sm['scheduleLocationId'] as String?,
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    return TrailManifest(locations: locs);
  }
}
