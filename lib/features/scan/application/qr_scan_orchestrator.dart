import 'package:flutter/foundation.dart';
import 'package:mq_journey/features/scan/domain/contracts/progress_api.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_validation_result.dart';

typedef QrValidate =
    Future<QrValidationResult> Function(
      String raw,
      bool Function(String locationId) isAllowlisted,
    );

@immutable
class RecordedQrVisit {
  const RecordedQrVisit({required this.locationId, required this.isNewVisit});

  final String locationId;
  final bool isNewVisit;
}

sealed class QrScanOutcome {
  const QrScanOutcome();
}

@immutable
final class QrScanAccepted extends QrScanOutcome {
  const QrScanAccepted(this.locationId, {required this.isNewVisit});

  final String locationId;
  final bool isNewVisit;

  @override
  bool operator ==(Object other) =>
      other is QrScanAccepted &&
      other.locationId == locationId &&
      other.isNewVisit == isNewVisit;

  @override
  int get hashCode => Object.hash(locationId, isNewVisit);
}

@immutable
final class QrScanRejected extends QrScanOutcome {
  const QrScanRejected(this.reason);

  final QrRejectReason reason;

  @override
  bool operator ==(Object other) =>
      other is QrScanRejected && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

@immutable
final class QrScanIgnored extends QrScanOutcome {
  const QrScanIgnored();

  @override
  bool operator ==(Object other) => other is QrScanIgnored;

  @override
  int get hashCode => runtimeType.hashCode;
}

@immutable
final class QrScanSaveFailed extends QrScanOutcome {
  const QrScanSaveFailed(this.locationId);

  final String locationId;

  @override
  bool operator ==(Object other) =>
      other is QrScanSaveFailed && other.locationId == locationId;

  @override
  int get hashCode => locationId.hashCode;
}

class QrScanOrchestrator {
  QrScanOrchestrator({
    required QrValidate validate,
    required Future<TrailManifest> Function() loadTrail,
    required ProgressApi progressApi,
    required DateTime Function() clock,
    required void Function(String route) navigate,
    required void Function(RecordedQrVisit visit) onRecorded,
  }) : _validate = validate,
       _loadTrail = loadTrail,
       _progressApi = progressApi,
       _clock = clock,
       _navigate = navigate,
       _onRecorded = onRecorded;

  final QrValidate _validate;
  final Future<TrailManifest> Function() _loadTrail;
  final ProgressApi _progressApi;
  final DateTime Function() _clock;
  final void Function(String route) _navigate;
  final void Function(RecordedQrVisit visit) _onRecorded;
  bool _handling = false;

  Future<QrScanOutcome> handleCandidate(String raw) async {
    if (_handling) return const QrScanIgnored();
    _handling = true;
    try {
      final trail = await _loadTrail();
      final validation = await _validate(raw, trail.contains);
      if (validation case InvalidTrailQr(:final reason)) {
        return QrScanRejected(reason);
      }
      final valid = validation as ValidTrailQr;
      final location = trail.byId(valid.locationId);
      if (location == null) {
        return const QrScanRejected(QrRejectReason.locationNotOnTrail);
      }

      try {
        final isNewVisit = await _progressApi.recordVisit(
          VisitEvent(
            locationId: location.locationId,
            buildingId: location.buildingId,
            scannedAt: _clock().toUtc(),
            source: VisitSource.qrScan,
          ),
        );
        _navigate('/location/${location.locationId}');
        _onRecorded(
          RecordedQrVisit(
            locationId: location.locationId,
            isNewVisit: isNewVisit,
          ),
        );
        return QrScanAccepted(location.locationId, isNewVisit: isNewVisit);
      } catch (_) {
        _navigate('/location/${location.locationId}');
        return QrScanSaveFailed(location.locationId);
      }
    } catch (_) {
      return const QrScanRejected(QrRejectReason.internalFailClosed);
    } finally {
      _handling = false;
    }
  }
}
