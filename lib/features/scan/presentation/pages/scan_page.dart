import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/data/adapters/settings_progress_api_adapter.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';
import 'package:mq_journey/features/scan/presentation/widgets/scanner_view.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:permission_handler/permission_handler.dart';

enum _ScanState {
  permissionRequired,
  scanning,
  decoding,
  denied,
  notOnTrail,
  decodeError,
}

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  late final MobileScannerController _scannerController;
  _ScanState _currentScanState = _ScanState.scanning;
  bool _torchOn = false;
  int _lastProcessed = 0;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _lifecycleListener = AppLifecycleListener(
      onPause: _onAppPause,
      onResume: _onAppResume,
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onAppPause() {
    _scannerController.pause();
  }

  void _onAppResume() {
    _scannerController.start();
  }

  void _toggleTorch() {
    setState(() => _torchOn = !_torchOn);
    _scannerController.toggleTorch();
  }

  String? _parseLocationId(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.host == 'mq.edu.au' || uri.scheme == 'io.mqjourney') {
      return uri.queryParameters['locationId'];
    }
    return null;
  }

  Future<void> _onDetectBarcode(String raw) async {
    setState(() => _currentScanState = _ScanState.decoding);

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcessed < 1500) return;
    _lastProcessed = now;

    final locationId = _parseLocationId(raw);
    if (locationId == null) {
      setState(() => _currentScanState = _ScanState.decodeError);
      return;
    }

    final manifest = await ref.read(trailManifestProvider.future);
    if (!manifest.contains(locationId)) {
      setState(() => _currentScanState = _ScanState.notOnTrail);
      return;
    }

    final visit = VisitEvent(locationId: locationId, scannedAt: DateTime.now());
    await ref.read(progressApiProvider).recordVisit(visit);

    if (!mounted) return;
    context.go('/location/$locationId');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) {
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.scanQrCta),
          actions: [
            if (_currentScanState == _ScanState.scanning)
              IconButton(
                icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                onPressed: _toggleTorch,
              ),
          ],
        ),
        body: _buildBody(l10n),
      ),
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
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(l10n.scanDecodeError),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    setState(() => _currentScanState = _ScanState.scanning),
                child: const Text('Scan again'),
              ),
            ],
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
                onPressed: () =>
                    setState(() => _currentScanState = _ScanState.scanning),
                child: const Text('Scan again'),
              ),
            ],
          ),
        );
      case _ScanState.decoding:
        return const Center(child: CircularProgressIndicator());
      case _ScanState.permissionRequired:
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
