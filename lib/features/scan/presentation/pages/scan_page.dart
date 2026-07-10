import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/active_shell_branch_index_provider.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/scan/application/pending_stamp_award_controller.dart';
import 'package:mq_journey/features/scan/application/qr_scan_orchestrator.dart';
import 'package:mq_journey/features/scan/data/adapters/settings_progress_api_adapter.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_validation_result.dart';
import 'package:mq_journey/features/scan/domain/services/scan_branch_lifecycle.dart';
import 'package:mq_journey/features/scan/presentation/widgets/scanner_view.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:permission_handler/permission_handler.dart';

enum _ScanState { scanning, decoding, denied, notOnTrail, decodeError }

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  late final MobileScannerController _scannerController;
  late final QrScanOrchestrator _orchestrator;
  _ScanState _currentScanState = _ScanState.scanning;
  QrRejectReason? _lastRejectReason;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(autoStart: false);
    final verifier = ref.read(qrSignatureVerifierProvider);
    _orchestrator = QrScanOrchestrator(
      validate: (raw, isAllowlisted) =>
          verifier.validate(raw, isAllowlisted: isAllowlisted),
      loadTrail: () => ref.read(trailManifestProvider.future),
      progressApi: ref.read(progressApiProvider),
      clock: DateTime.now,
      navigate: (route) {
        if (mounted) context.go(route);
      },
      onRecorded: (visit) {
        ref
            .read(pendingStampAwardProvider.notifier)
            .setNotice(
              PendingStampNotice(
                locationId: visit.locationId,
                isNewVisit: visit.isNewVisit,
              ),
            );
      },
    );
    _lifecycleListener = AppLifecycleListener(
      onPause: _onAppPause,
      onResume: _onAppResume,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startForScanIntent());
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onAppPause() {
    unawaited(_stopScanner());
  }

  void _onAppResume() {
    if (ref.read(activeShellBranchIndexProvider) != ShellBranchIndex.scan) {
      return;
    }
    if (!_scannerController.value.hasCameraPermission) return;
    unawaited(_startForScanIntent());
  }

  Future<void> _stopScanner() async {
    if (!_scannerController.value.hasCameraPermission) return;
    try {
      if (_scannerController.value.torchState == TorchState.on) {
        await _scannerController.toggleTorch();
      }
      await _scannerController.stop();
    } on MobileScannerException {
      // Lifecycle changes can race platform camera teardown; stay fail-safe.
    }
  }

  Future<void> _startForScanIntent() async {
    if (!mounted) return;
    try {
      await _scannerController.start();
    } on MobileScannerException {
      // ScannerView's errorBuilder owns the localized permission/error state.
    }
  }

  void _toggleTorch() {
    _scannerController.toggleTorch();
  }

  Future<void> _onDetectBarcode(String raw) async {
    setState(() => _currentScanState = _ScanState.decoding);
    final outcome = await _orchestrator.handleCandidate(raw);
    if (!mounted) return;
    switch (outcome) {
      case QrScanRejected(:final reason):
        _lastRejectReason = reason;
        setState(
          () => _currentScanState = reason == QrRejectReason.locationNotOnTrail
              ? _ScanState.notOnTrail
              : _ScanState.decodeError,
        );
      case QrScanSaveFailed(:final locationId):
        ref
            .read(pendingStampAwardProvider.notifier)
            .setNotice(
              PendingStampNotice(
                locationId: locationId,
                isNewVisit: false,
                saveFailed: true,
              ),
            );
      case QrScanIgnored():
        setState(() => _currentScanState = _ScanState.scanning);
      case QrScanAccepted():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen<int>(activeShellBranchIndexProvider, (previous, next) {
      switch (scanBranchLifecycleAction(
        previousIndex: previous,
        nextIndex: next,
        scanBranchIndex: ShellBranchIndex.scan,
      )) {
        case ScanBranchLifecycleAction.pause:
          _onAppPause();
        case ScanBranchLifecycleAction.resume:
          _onAppResume();
        case ScanBranchLifecycleAction.none:
          break;
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanQrCta),
        actions: [
          if (_currentScanState == _ScanState.scanning)
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scannerController,
              builder: (context, state, _) {
                final torchOn = state.torchState == TorchState.on;
                return IconButton(
                  icon: Icon(torchOn ? Icons.flash_on : Icons.flash_off),
                  onPressed: _toggleTorch,
                );
              },
            ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    switch (_currentScanState) {
      case _ScanState.denied:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text(l10n.scanPermissionDenied),
              const SizedBox(height: 8),
              Text(
                l10n.scanPermissionDeniedDesc,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async => await openAppSettings(),
                child: Text(l10n.scanOpenSettings),
              ),
            ],
          ),
        );
      case _ScanState.decodeError:
        final message = switch (_lastRejectReason) {
          QrRejectReason.unsupportedScheme ||
          QrRejectReason.unsupportedHost ||
          QrRejectReason.invalidPath => l10n.scanNotMqCode,
          QrRejectReason.unsupportedVersion ||
          QrRejectReason.unknownKeyId => l10n.scanUnsupportedCode,
          QrRejectReason.invalidSignatureEncoding ||
          QrRejectReason.signatureMismatch => l10n.scanUnverifiedCode,
          _ => l10n.scanDecodeError,
        };
        return Center(
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _currentScanState = _ScanState.scanning);
                    unawaited(_startForScanIntent());
                  },
                  child: Text(l10n.scanAgain),
                ),
              ],
            ),
          ),
        );
      case _ScanState.notOnTrail:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(l10n.scanNotOnTrail),
              const SizedBox(height: 8),
              Text(
                l10n.scanNotOnTrailDesc,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _currentScanState = _ScanState.scanning);
                  unawaited(_startForScanIntent());
                },
                child: Text(l10n.scanAgain),
              ),
            ],
          ),
        );
      case _ScanState.decoding:
        return const Center(child: CircularProgressIndicator());
      case _ScanState.scanning:
        return Stack(
          children: [
            ScannerView(
              controller: _scannerController,
              onDetect: _onDetectBarcode,
              onPermissionDenied: () =>
                  setState(() => _currentScanState = _ScanState.denied),
            ),
            const _DimSurround(reticleColor: Colors.white),
            Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _DimSurround extends StatelessWidget {
  const _DimSurround({required this.reticleColor});
  final Color reticleColor;

  @override
  Widget build(BuildContext context) {
    const r = 240.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cx = (w - r) / 2;
        final cy = (h - r) / 2;
        const dim = Colors.black54;
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: w,
              height: cy,
              child: Container(color: dim),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              width: w,
              height: cy,
              child: Container(color: dim),
            ),
            Positioned(
              left: 0,
              top: cy,
              width: cx,
              height: r,
              child: Container(color: dim),
            ),
            Positioned(
              right: 0,
              top: cy,
              width: cx,
              height: r,
              child: Container(color: dim),
            ),
          ],
        );
      },
    );
  }
}
