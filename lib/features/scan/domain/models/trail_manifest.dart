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
  final String title;
  final List<String> photos;
  final String? arSceneId; // this location's own entrance scene (a node id)
  final List<OpenDayStop> stops;

  const TrailLocation({
    required this.locationId,
    this.buildingId,
    required this.title,
    this.photos = const [],
    this.arSceneId,
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

  factory TrailManifest.fromJson(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final locs = (json['locations'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          return TrailLocation(
            locationId: m['locationId'] as String,
            buildingId: m['buildingId'] as String?,
            title: m['title'] as String,
            photos: ((m['photos'] as List?) ?? const [])
                .map((p) => p as String)
                .toList(growable: false),
            arSceneId: m['arSceneId'] as String?,
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
