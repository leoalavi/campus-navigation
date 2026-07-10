import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/application/qr_scan_orchestrator.dart';

import 'qr_pipeline_test_support.dart';

void main() {
  test('ten concurrent frames produce one visit, route, and award', () async {
    final fixtures = QrPipelineFixtures.load();
    final fixture = fixtures.locations.first;
    final progress = PipelineProgress();
    final validationStarted = Completer<void>();
    final releaseValidation = Completer<void>();
    var validationCalls = 0;
    final routes = <String>[];
    final notices = <RecordedQrVisit>[];

    final orchestrator = QrScanOrchestrator(
      validate: (raw, allowlist) async {
        validationCalls++;
        if (!validationStarted.isCompleted) validationStarted.complete();
        await releaseValidation.future;
        return PipelineProbe(
          fixtures: fixtures,
        ).verifier.validate(raw, isAllowlisted: allowlist);
      },
      loadTrail: () async => fixtures.trail,
      progressApi: progress,
      clock: () => DateTime.utc(2026, 7, 10),
      navigate: routes.add,
      onRecorded: notices.add,
    );

    final first = orchestrator.handleCandidate(fixture.uri);
    await validationStarted.future;
    final duplicates = List.generate(
      9,
      (_) => orchestrator.handleCandidate(fixture.uri),
    );
    releaseValidation.complete();

    expect(await first, isA<QrScanAccepted>());
    expect(await Future.wait(duplicates), everyElement(const QrScanIgnored()));
    expect(validationCalls, 1);
    expect(progress.attempts, hasLength(1));
    expect(routes, ['/location/${fixture.location.locationId}']);
    expect(notices, hasLength(1));
    expect(notices.single.isNewVisit, isTrue);
  });
}
