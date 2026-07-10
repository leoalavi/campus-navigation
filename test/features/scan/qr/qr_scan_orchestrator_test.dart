import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/application/qr_scan_orchestrator.dart';
import 'package:mq_journey/features/scan/domain/contracts/progress_api.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_progress_api.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_public_key_registry.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_signature_verifier.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_validation_result.dart';

void main() {
  const manifest = TrailManifest(
    locations: [
      TrailLocation(
        locationId: 'wallys-1',
        buildingId: 'wallys-1',
        title: "1 Wally's Walk",
      ),
    ],
  );
  late _Progress progress;
  late List<String> routes;
  late List<RecordedQrVisit> notices;

  setUp(() {
    progress = _Progress();
    routes = [];
    notices = [];
  });

  QrScanOrchestrator orchestrator(QrValidate validate) => QrScanOrchestrator(
    validate: validate,
    loadTrail: () async => manifest,
    progressApi: progress,
    clock: () => DateTime.utc(2026, 7, 10, 2),
    navigate: routes.add,
    onRecorded: notices.add,
  );

  test('valid first scan records, routes, and reports one new visit', () async {
    final subject = orchestrator(
      (_, allowlist) async => allowlist('wallys-1')
          ? const ValidTrailQr('wallys-1', 'key')
          : const InvalidTrailQr(QrRejectReason.locationNotOnTrail),
    );

    final outcome = await subject.handleCandidate('signed');

    expect(outcome, const QrScanAccepted('wallys-1', isNewVisit: true));
    expect(progress.events, hasLength(1));
    expect(progress.events.single.locationId, 'wallys-1');
    expect(progress.events.single.source, VisitSource.qrScan);
    expect(routes, ['/location/wallys-1']);
    expect(notices.single.isNewVisit, isTrue);
    expect(notices.single.locationId, 'wallys-1');
  });

  test(
    'invalid scan causes no progress, route, or notice side effect',
    () async {
      final subject = orchestrator(
        (_, _) async => const InvalidTrailQr(QrRejectReason.signatureMismatch),
      );

      final outcome = await subject.handleCandidate('tampered');

      expect(outcome, const QrScanRejected(QrRejectReason.signatureMismatch));
      expect(progress.events, isEmpty);
      expect(routes, isEmpty);
      expect(notices, isEmpty);
    },
  );

  test('duplicate detections during handling produce one visit', () async {
    final validation = Completer<QrValidationResult>();
    final subject = orchestrator((_, _) => validation.future);

    final first = subject.handleCandidate('signed');
    final duplicate = await subject.handleCandidate('signed');
    validation.complete(const ValidTrailQr('wallys-1', 'key'));
    await first;

    expect(duplicate, const QrScanIgnored());
    expect(progress.events, hasLength(1));
    expect(routes, hasLength(1));
  });

  test('local persistence failure opens card without reward notice', () async {
    progress.error = StateError('disk full');
    final subject = orchestrator(
      (_, _) async => const ValidTrailQr('wallys-1', 'key'),
    );

    final outcome = await subject.handleCandidate('signed');

    expect(outcome, const QrScanSaveFailed('wallys-1'));
    expect(routes, ['/location/wallys-1']);
    expect(notices, isEmpty);
  });

  test('all nine production payloads route and award exactly once', () async {
    final trail = TrailManifest.fromJson(
      File('assets/data/open_day_trail.json').readAsStringSync(),
    );
    final payloadDocument =
        jsonDecode(
              File('assets/qr/open_day/2026/manifest.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final payloads = (payloadDocument['locations'] as List)
        .cast<Map<String, dynamic>>();
    final verifier = QrSignatureVerifier(publicKeys: qrPublicKeys);
    final progress = FakeProgressApi();
    addTearDown(progress.dispose);

    for (final entry in payloads) {
      final locationId = entry['locationId']! as String;
      final routes = <String>[];
      final notices = <RecordedQrVisit>[];
      final subject = QrScanOrchestrator(
        validate: (raw, allowlist) =>
            verifier.validate(raw, isAllowlisted: allowlist),
        loadTrail: () async => trail,
        progressApi: progress,
        clock: () => DateTime.utc(2026, 7, 10, 2),
        navigate: routes.add,
        onRecorded: notices.add,
      );

      expect(
        await subject.handleCandidate(entry['uri']! as String),
        QrScanAccepted(locationId, isNewVisit: true),
      );
      expect(
        await subject.handleCandidate(entry['uri']! as String),
        QrScanAccepted(locationId, isNewVisit: false),
      );
      expect(routes, ['/location/$locationId', '/location/$locationId']);
      expect(notices.map((notice) => notice.isNewVisit), [true, false]);
    }
  });
}

class _Progress implements ProgressApi {
  final events = <VisitEvent>[];
  Object? error;
  bool isNewVisit = true;

  @override
  Future<bool> recordVisit(VisitEvent event) async {
    events.add(event);
    if (error != null) throw error!;
    return isNewVisit;
  }

  @override
  Stream<VisitedState> watch(String locationId) => const Stream.empty();
}
