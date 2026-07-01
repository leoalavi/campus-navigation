import 'package:flutter/foundation.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';

@immutable
class StampAward {
  final StampCatalogEntry stamp;
  final int collectedCount;
  final int total;
  final bool isFirst;
  final bool isComplete;

  const StampAward({
    required this.stamp,
    required this.collectedCount,
    required this.total,
    required this.isFirst,
    required this.isComplete,
  });
}

/// Computes the stamp award for a confirmed visit, or `null` when the
/// visited location isn't one of the catalogued Open Day stamp locations.
///
/// [visitedLocationCodesAfterVisit] must be read AFTER the local write
/// completes (it should already include this visit's code) and may use
/// any casing — comparison is case-insensitive to bridge
/// `UserPreferences.visitedLocationCodes` (stored upper-case) against
/// `StampCatalogEntry.locationId` (stored lower-case, e.g. "wallys-1").
StampAward? computeStampAward({
  required String visitedCode,
  required List<String> visitedLocationCodesAfterVisit,
  required List<StampCatalogEntry> catalog,
}) {
  final normalizedVisitedCode = visitedCode.trim().toUpperCase();
  StampCatalogEntry? entry;
  for (final candidate in catalog) {
    if (candidate.locationId.toUpperCase() == normalizedVisitedCode) {
      entry = candidate;
      break;
    }
  }
  if (entry == null) return null;

  final catalogIds = {for (final c in catalog) c.locationId.toUpperCase()};
  final collected = <String>{
    for (final code in visitedLocationCodesAfterVisit)
      if (catalogIds.contains(code.trim().toUpperCase()))
        code.trim().toUpperCase(),
  };

  final collectedCount = collected.length;
  return StampAward(
    stamp: entry,
    collectedCount: collectedCount,
    total: catalog.length,
    isFirst: collectedCount == 1,
    isComplete: collectedCount == catalog.length,
  );
}
