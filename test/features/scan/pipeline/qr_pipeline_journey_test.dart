import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/application/qr_scan_orchestrator.dart';

import 'qr_pipeline_test_support.dart';

void main() {
  final fixtures = QrPipelineFixtures.load();

  Future<void> proveOrder(List<QrPipelineFixture> order) async {
    final probe = PipelineProbe(fixtures: fixtures);
    for (var index = 0; index < order.length; index++) {
      final fixture = order[index];
      expect(
        await probe.orchestrator.handleCandidate(fixture.uri),
        QrScanAccepted(fixture.location.locationId, isNewVisit: true),
      );
      expect(
        probe.progress.visited,
        order.take(index + 1).map((item) => item.location.locationId).toSet(),
      );
      expect(probe.awards, hasLength(index + 1));
      expect(probe.awards.last.stamp.locationId, fixture.location.locationId);
    }
    expect(probe.progress.remoteRows, probe.progress.visited);
    expect(probe.awards.where((award) => award.isComplete), hasLength(1));
  }

  test('canonical nine-location journey completes once', () async {
    await proveOrder(fixtures.locations);
  });

  for (final seed in <int>[7, 29, 2026]) {
    test('seeded order $seed completes once without contamination', () async {
      final order = fixtures.locations.toList()..shuffle(Random(seed));
      await proveOrder(order);
    });
  }
}
