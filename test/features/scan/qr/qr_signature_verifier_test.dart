import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_signature_verifier.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_validation_result.dart';

void main() {
  const keyId = 'mqj-open-day-2026-01';
  final publicKey = base64Url.decode(
    base64Url.normalize('bTAqtYC6rOfII9ntwaY82Xl_N8-pmklFKkgjNZkPJGY'),
  );
  const validSignature =
      '9Hk61FOS0hXuaoggjesvqewOBuLbHqMfOTz2p_7ocwMWFB-pLN8EzBnJLvYoOtOuRMdB7DAmNB9wiVie3ADcBw';
  const offTrailSignature =
      '-fH5ZT0VMCQl4XH0o_zPY9ojvAjLlz3Y3rx0JGZPZM9YaWYXzobFFtMOA8UtKjGbGzZHPqkwRCfP52jFGqgpBA';
  late QrSignatureVerifier verifier;

  String uri(String locationId, String signature) =>
      'io.mqjourney://open-day/location/$locationId?v=1&kid=$keyId&sig=$signature';

  setUp(() {
    verifier = QrSignatureVerifier(publicKeys: {keyId: publicKey});
  });

  test('accepts a valid signature for an allowlisted location', () async {
    final result = await verifier.validate(
      uri('wallys-1', validSignature),
      isAllowlisted: (id) => id == 'wallys-1',
    );

    expect(
      result,
      isA<ValidTrailQr>()
          .having((value) => value.locationId, 'locationId', 'wallys-1')
          .having((value) => value.keyId, 'keyId', keyId),
    );
  });

  test('rejects a location mutation before allowlist resolution', () async {
    var allowlistCalled = false;
    final result = await verifier.validate(
      uri('wallys-21', validSignature),
      isAllowlisted: (_) {
        allowlistCalled = true;
        return true;
      },
    );

    expect(
      result,
      isA<InvalidTrailQr>().having(
        (value) => value.reason,
        'reason',
        QrRejectReason.signatureMismatch,
      ),
    );
    expect(allowlistCalled, isFalse);
  });

  test('rejects a signed location absent from the trail', () async {
    final result = await verifier.validate(
      uri('off-trail', offTrailSignature),
      isAllowlisted: (_) => false,
    );

    expect(
      result,
      isA<InvalidTrailQr>().having(
        (value) => value.reason,
        'reason',
        QrRejectReason.locationNotOnTrail,
      ),
    );
  });

  test('arbitrary input never throws', () async {
    for (final raw in <String>['', '\u0000', '😀', '://', 'not a uri']) {
      await expectLater(
        verifier.validate(raw, isAllowlisted: (_) => true),
        completion(isA<InvalidTrailQr>()),
      );
    }
  });
}
