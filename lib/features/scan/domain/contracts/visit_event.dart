import 'package:flutter/foundation.dart';

enum VisitSource { qrScan, arrivalDetection }

@immutable
class VisitEvent {
  final String locationId;
  final String? buildingId;
  final DateTime scannedAt;
  final VisitSource source;

  const VisitEvent({
    required this.locationId,
    this.buildingId,
    required this.scannedAt,
    this.source = VisitSource.qrScan,
  });
}
