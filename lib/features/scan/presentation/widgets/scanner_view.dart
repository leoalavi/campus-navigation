import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';

class ScannerView extends StatelessWidget {
  const ScannerView({
    super.key,
    required this.controller,
    required this.onDetect,
    this.onPermissionDenied,
  });

  final MobileScannerController controller;
  final void Function(String value) onDetect;
  final VoidCallback? onPermissionDenied;

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: controller,
      fit: BoxFit.cover,
      onDetect: (barcode) {
        final raw = barcode.barcodes.firstOrNull?.rawValue;
        if (raw != null) onDetect(raw);
      },
      errorBuilder: (context, error) {
        final l10n = AppLocalizations.of(context)!;
        if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onPermissionDenied,
                  child: Text(l10n.scanOpenSettings),
                ),
              ],
            ),
          );
        }
        return const Center(
          child: Icon(Icons.error, size: 64, color: Colors.red),
        );
      },
      placeholderBuilder: (context) {
        return Container(color: Colors.black);
      },
    );
  }
}
