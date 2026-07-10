import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_public_key_registry.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_signature_verifier.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_validation_result.dart';

void main() {
  test(
    'public manifest binds nine valid signed payloads to deterministic SVGs',
    () async {
      final directory = Directory('assets/qr/open_day/2026');
      final manifest =
          jsonDecode(File('${directory.path}/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      final locations = (manifest['locations'] as List)
          .cast<Map<String, dynamic>>();
      final verifier = QrSignatureVerifier(publicKeys: qrPublicKeys);

      expect(manifest['schema'], 'mqjourney.open-day.qr-manifest.v1');
      expect(manifest['keyId'], 'mqj-open-day-2026-01');
      expect(manifest['count'], 9);
      expect(locations, hasLength(9));
      expect(
        directory.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.svg'),
        ),
        hasLength(9),
      );

      for (final entry in locations) {
        final uri = entry['uri']! as String;
        final locationId = entry['locationId']! as String;
        final svg = File(
          '${directory.path}/${entry['file']}',
        ).readAsBytesSync();
        expect(
          sha256.convert(utf8.encode(uri)).toString(),
          entry['payloadSha256'],
        );
        expect(sha256.convert(svg).toString(), entry['svgSha256']);
        expect(
          await verifier.validate(uri, isAllowlisted: (id) => id == locationId),
          isA<ValidTrailQr>().having(
            (value) => value.locationId,
            'locationId',
            locationId,
          ),
        );
      }
    },
  );
}
