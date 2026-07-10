import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/application/qr_scan_orchestrator.dart';

import 'qr_pipeline_test_support.dart';

void main() {
  test(
    'offline visit syncs once and reconnect retries remain idempotent',
    () async {
      final fixtures = QrPipelineFixtures.load();
      final fixture = fixtures.locations.first;
      final progress = PipelineProgress(online: false);
      final probe = PipelineProbe(fixtures: fixtures, progress: progress);

      expect(
        await probe.orchestrator.handleCandidate(fixture.uri),
        QrScanAccepted(fixture.location.locationId, isNewVisit: true),
      );
      expect(progress.visited, {fixture.location.locationId});
      expect(progress.pendingRows, {fixture.location.locationId});
      expect(progress.remoteRows, isEmpty);
      expect(probe.awards, hasLength(1));

      expect(
        await probe.orchestrator.handleCandidate(fixture.uri),
        QrScanAccepted(fixture.location.locationId, isNewVisit: false),
      );
      expect(progress.pendingRows, {fixture.location.locationId});
      expect(probe.awards, hasLength(1));

      progress.online = true;
      progress.flush();
      progress.flush();
      expect(progress.pendingRows, isEmpty);
      expect(progress.remoteRows, {fixture.location.locationId});
      expect(probe.awards, hasLength(1));
    },
  );

  test('remote row hydrated on reinstall prevents a second award', () async {
    final fixtures = QrPipelineFixtures.load();
    final fixture = fixtures.locations.first;
    final progress = PipelineProgress()
      ..remoteRows.add(fixture.location.locationId)
      ..hydrateFromRemote();
    final probe = PipelineProbe(fixtures: fixtures, progress: progress);

    expect(
      await probe.orchestrator.handleCandidate(fixture.uri),
      QrScanAccepted(fixture.location.locationId, isNewVisit: false),
    );
    expect(progress.remoteRows, {fixture.location.locationId});
    expect(progress.pendingRows, isEmpty);
    expect(probe.awards, isEmpty);
  });
}
