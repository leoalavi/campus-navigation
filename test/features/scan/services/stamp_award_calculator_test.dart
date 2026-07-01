import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/domain/services/stamp_award_calculator.dart';

void main() {
  const catalog = [
    StampCatalogEntry(
      locationId: 'wallys-1',
      title: "1 Wally's Walk",
      mapRef: 'K27',
      stampAsset: 'assets/stamps/wallys-1.png',
    ),
    StampCatalogEntry(
      locationId: 'wallys-25',
      title: "25 Wally's Walk",
      mapRef: 'N12',
      stampAsset: 'assets/stamps/wallys-25.png',
    ),
  ];

  test('returns null when the visited code is not in the catalogue', () {
    final award = computeStampAward(
      visitedCode: 'not-a-stamp-location',
      visitedLocationCodesAfterVisit: const ['NOT-A-STAMP-LOCATION'],
      catalog: catalog,
    );
    expect(award, isNull);
  });

  test('marks the first collected stamp as isFirst and not isComplete', () {
    final award = computeStampAward(
      visitedCode: 'wallys-1',
      visitedLocationCodesAfterVisit: const ['WALLYS-1'],
      catalog: catalog,
    );
    expect(award, isNotNull);
    expect(award!.stamp.locationId, 'wallys-1');
    expect(award.collectedCount, 1);
    expect(award.total, 2);
    expect(award.isFirst, isTrue);
    expect(award.isComplete, isFalse);
  });

  test('marks the final stamp as isComplete and not isFirst', () {
    final award = computeStampAward(
      visitedCode: 'wallys-25',
      visitedLocationCodesAfterVisit: const ['WALLYS-1', 'WALLYS-25'],
      catalog: catalog,
    );
    expect(award, isNotNull);
    expect(award!.collectedCount, 2);
    expect(award.isFirst, isFalse);
    expect(award.isComplete, isTrue);
  });

  test('matching is case-insensitive between catalogue and visited codes', () {
    final award = computeStampAward(
      visitedCode: 'WALLYS-1',
      visitedLocationCodesAfterVisit: const ['wallys-1'],
      catalog: catalog,
    );
    expect(award, isNotNull);
    expect(award!.collectedCount, 1);
  });

  test('ignores visited codes that are not part of the catalogue', () {
    final award = computeStampAward(
      visitedCode: 'wallys-1',
      visitedLocationCodesAfterVisit: const ['WALLYS-1', 'SOME-OTHER-BUILDING'],
      catalog: catalog,
    );
    expect(award, isNotNull);
    expect(award!.collectedCount, 1);
  });
}
