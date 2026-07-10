import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/application/qr_scan_orchestrator.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_validation_result.dart';

import 'qr_pipeline_test_support.dart';

void main() {
  const offTrail =
      'io.mqjourney://open-day/location/off-trail?v=1&kid='
      'mqj-open-day-2026-01&sig='
      '-fH5ZT0VMCQl4XH0o_zPY9ojvAjLlz3Y3rx0JGZPZM9YaWYXzobFFtMOA8UtKjGbGzZHPqkwRCfP52jFGqgpBA';

  test('adversarial payloads fail closed without any side effect', () async {
    final fixtures = QrPipelineFixtures.load();
    final valid = fixtures.locations.first.uri;
    final cases = <String, (String, QrRejectReason)>{
      'malformed': ('not a uri', QrRejectReason.malformedUri),
      'wrong scheme': (
        valid.replaceFirst('io.mqjourney:', 'https:'),
        QrRejectReason.unsupportedScheme,
      ),
      'wrong host': (
        valid.replaceFirst('open-day', 'example.com'),
        QrRejectReason.unsupportedHost,
      ),
      'wrong path': (
        valid.replaceFirst('/location/', '/place/'),
        QrRejectReason.invalidPath,
      ),
      'duplicate query key': (
        '$valid&sig=duplicate',
        QrRejectReason.duplicateQueryKey,
      ),
      'unknown query key': ('$valid&extra=1', QrRejectReason.unknownQueryKey),
      'location mutation': (
        valid.replaceFirst(
          fixtures.locations.first.location.locationId,
          '${fixtures.locations.first.location.locationId}-tampered',
        ),
        QrRejectReason.signatureMismatch,
      ),
      'unknown key': (
        valid.replaceFirst('mqj-open-day-2026-02', 'unknown-key'),
        QrRejectReason.unknownKeyId,
      ),
      'signed off trail': (offTrail, QrRejectReason.locationNotOnTrail),
    };

    for (final MapEntry(key: name, value: testCase) in cases.entries) {
      final probe = PipelineProbe(fixtures: fixtures);
      final outcome = await probe.orchestrator.handleCandidate(testCase.$1);
      expect(outcome, QrScanRejected(testCase.$2), reason: name);
      expect(probe.progress.attempts, isEmpty, reason: name);
      expect(probe.routes, isEmpty, reason: name);
      expect(probe.notices, isEmpty, reason: name);
      expect(probe.awards, isEmpty, reason: name);
    }
  });

  test('unexpected verifier failure is rejected fail closed', () async {
    final fixtures = QrPipelineFixtures.load();
    final progress = PipelineProgress();
    final routes = <String>[];
    final notices = <RecordedQrVisit>[];
    final orchestrator = QrScanOrchestrator(
      validate: (_, _) => throw StateError('verifier unavailable'),
      loadTrail: () async => fixtures.trail,
      progressApi: progress,
      clock: DateTime.now,
      navigate: routes.add,
      onRecorded: notices.add,
    );

    expect(
      await orchestrator.handleCandidate(fixtures.locations.first.uri),
      const QrScanRejected(QrRejectReason.internalFailClosed),
    );
    expect(progress.attempts, isEmpty);
    expect(routes, isEmpty);
    expect(notices, isEmpty);
  });
}
