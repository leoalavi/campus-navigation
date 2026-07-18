import 'package:flutter/foundation.dart';

@immutable
class LocationContent {
  final String locationId;
  final String title;
  final String heroImageAsset;
  final String shortDescription;
  final String? buildingId;
  final String? mapBuildingCode;
  final String? fullScheduleUrl;

  const LocationContent({
    required this.locationId,
    required this.title,
    required this.heroImageAsset,
    required this.shortDescription,
    this.buildingId,
    this.mapBuildingCode,
    this.fullScheduleUrl,
  });
}
