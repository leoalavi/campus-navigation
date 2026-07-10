import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/application/qr_scan_orchestrator.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';

import 'qr_pipeline_test_support.dart';

void main() {
  test(
    'all nine first scans conserve identity and repeats award nothing',
    () async {
      final fixtures = QrPipelineFixtures.load();
      final probe = PipelineProbe(fixtures: fixtures);

      for (final fixture in fixtures.locations) {
        final first = await probe.orchestrator.handleCandidate(fixture.uri);
        expect(
          first,
          QrScanAccepted(fixture.location.locationId, isNewVisit: true),
        );
        final event = probe.progress.attempts.last;
        final notice = probe.notices.last;
        final award = probe.awards.last;
        final route = probe.routes.last;

        expect(event.locationId, fixture.location.locationId);
        expect(event.buildingId, fixture.location.buildingId);
        expect(event.source, VisitSource.qrScan);
        expect(
          event.scannedAt,
          DateTime.utc(2026, 7, 10, 0, 0, fixture.ordinal),
        );
        expect(route, '/location/${fixture.location.locationId}');
        expect(notice.locationId, fixture.location.locationId);
        expect(award.stamp.locationId, fixture.location.locationId);
        expect(award.stamp.title, fixture.location.title);
        expect(award.stamp.mapRef, fixture.stamp.mapRef);
        expect(award.collectedCount, fixture.ordinal);
        expect(probe.progress.visited.length, fixture.ordinal);
      }

      final firstPassAwardCount = probe.awards.length;
      for (final fixture in fixtures.locations) {
        final repeat = await probe.orchestrator.handleCandidate(fixture.uri);
        expect(
          repeat,
          QrScanAccepted(fixture.location.locationId, isNewVisit: false),
        );
        expect(probe.progress.visited, hasLength(fixtures.locations.length));
        expect(probe.awards, hasLength(firstPassAwardCount));
      }

      expect(
        probe.progress.visited,
        fixtures.locations
            .map((fixture) => fixture.location.locationId)
            .toSet(),
      );
      expect(probe.awards.where((award) => award.isComplete), hasLength(1));
    },
  );
}
