import 'dart:convert';
import 'dart:io';

import 'package:mq_journey/features/scan/application/qr_scan_orchestrator.dart';
import 'package:mq_journey/features/scan/domain/contracts/progress_api.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_public_key_registry.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_signature_verifier.dart';
import 'package:mq_journey/features/scan/domain/services/stamp_award_calculator.dart';

class QrPipelineFixture {
  const QrPipelineFixture({
    required this.ordinal,
    required this.location,
    required this.stamp,
    required this.uri,
  });

  final int ordinal;
  final TrailLocation location;
  final StampCatalogEntry stamp;
  final String uri;
}

class QrPipelineFixtures {
  QrPipelineFixtures._({
    required this.trail,
    required this.catalog,
    required this.locations,
  });

  final TrailManifest trail;
  final List<StampCatalogEntry> catalog;
  final List<QrPipelineFixture> locations;

  static QrPipelineFixtures load() {
    final trail = TrailManifest.fromJson(
      File('assets/data/open_day_trail.json').readAsStringSync(),
    );
    final stampDocument =
        jsonDecode(
              File(
                'assets/data/open_day_stamps_catalog.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final catalog = (stampDocument['stamps'] as List)
        .cast<Map<String, dynamic>>()
        .map(StampCatalogEntry.fromJson)
        .toList(growable: false);
    final qrDocument =
        jsonDecode(
              File('assets/qr/open_day/2026/manifest.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final qrEntries = (qrDocument['locations'] as List)
        .cast<Map<String, dynamic>>();

    final locations = <QrPipelineFixture>[];
    for (var index = 0; index < trail.locations.length; index++) {
      final location = trail.locations[index];
      locations.add(
        QrPipelineFixture(
          ordinal: index + 1,
          location: location,
          stamp: catalog.singleWhere(
            (entry) => entry.locationId == location.locationId,
          ),
          uri:
              qrEntries.singleWhere(
                    (entry) => entry['locationId'] == location.locationId,
                  )['uri']!
                  as String,
        ),
      );
    }
    return QrPipelineFixtures._(
      trail: trail,
      catalog: catalog,
      locations: locations,
    );
  }
}

class PipelineProgress implements ProgressApi {
  PipelineProgress({this.online = true});

  bool online;
  final Set<String> visited = <String>{};
  final Set<String> remoteRows = <String>{};
  final Set<String> pendingRows = <String>{};
  final List<VisitEvent> attempts = <VisitEvent>[];

  @override
  Future<bool> recordVisit(VisitEvent event) async {
    attempts.add(event);
    final isNew = visited.add(event.locationId);
    if (!isNew) return false;
    if (online) {
      remoteRows.add(event.locationId);
    } else {
      pendingRows.add(event.locationId);
    }
    return true;
  }

  void flush() {
    if (!online) return;
    remoteRows.addAll(pendingRows);
    pendingRows.clear();
  }

  void hydrateFromRemote() => visited.addAll(remoteRows);

  @override
  Stream<VisitedState> watch(String locationId) => Stream.value(
    VisitedState(visited: visited.contains(locationId), rewardEarned: false),
  );
}

class PipelineProbe {
  PipelineProbe({required this.fixtures, PipelineProgress? progress})
    : progress = progress ?? PipelineProgress(),
      verifier = QrSignatureVerifier(publicKeys: qrPublicKeys);

  final QrPipelineFixtures fixtures;
  final PipelineProgress progress;
  final QrSignatureVerifier verifier;
  final List<String> routes = <String>[];
  final List<RecordedQrVisit> notices = <RecordedQrVisit>[];
  final List<StampAward> awards = <StampAward>[];
  var _clockTick = 0;

  late final QrScanOrchestrator orchestrator = QrScanOrchestrator(
    validate: (raw, allowlist) =>
        verifier.validate(raw, isAllowlisted: allowlist),
    loadTrail: () async => fixtures.trail,
    progressApi: progress,
    clock: () => DateTime.utc(2026, 7, 10, 0, 0, ++_clockTick),
    navigate: routes.add,
    onRecorded: (notice) {
      notices.add(notice);
      if (!notice.isNewVisit) return;
      final award = computeStampAward(
        visitedCode: notice.locationId,
        visitedLocationCodesAfterVisit: progress.visited.toList(),
        catalog: fixtures.catalog,
      );
      if (award != null) awards.add(award);
    },
  );
}
