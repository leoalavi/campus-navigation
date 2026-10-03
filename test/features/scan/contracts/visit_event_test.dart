import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/features/scan/domain/contracts/visit_event.dart';

void main() {
  group('VisitEvent', () {
    test('defaults to qrScan source', () {
      final event = VisitEvent(
        locationId: 'lib-01',
        scannedAt: DateTime(2026, 6, 29),
      );
      expect(event.source, VisitSource.qrScan);
      expect(event.locationId, 'lib-01');
    });

    test('accepts explicit arrivalDetection source', () {
      final event = VisitEvent(
        locationId: 'lib-01',
        scannedAt: DateTime(2026, 6, 29),
        source: VisitSource.arrivalDetection,
      );
      expect(event.source, VisitSource.arrivalDetection);
    });

    test('accepts optional buildingId', () {
      final event = VisitEvent(
        locationId: 'lib-01',
        buildingId: 'c3a',
        scannedAt: DateTime(2026, 6, 29),
      );
      expect(event.buildingId, 'c3a');
    });
  });
}
