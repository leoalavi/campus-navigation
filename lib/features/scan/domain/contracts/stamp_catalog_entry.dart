import 'package:flutter/foundation.dart';

@immutable
class StampCatalogEntry {
  final String locationId;
  final String title;
  final String mapRef;
  final String stampAsset;

  const StampCatalogEntry({
    required this.locationId,
    required this.title,
    required this.mapRef,
    required this.stampAsset,
  });

  factory StampCatalogEntry.fromJson(Map<String, dynamic> json) {
    return StampCatalogEntry(
      locationId: json['locationId'] as String,
      title: json['title'] as String,
      mapRef: json['mapRef'] as String,
      stampAsset: json['stampAsset'] as String,
    );
  }
}
