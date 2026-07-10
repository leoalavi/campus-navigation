import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_validation_result.dart';
import 'package:mq_journey/features/scan/domain/qr/signed_qr_parser.dart';
import 'package:mq_journey/features/scan/domain/qr/signed_qr_payload.dart';

void main() {
  const keyId = 'mqj-open-day-2026-01';
  final signature = base64Url
      .encode(List<int>.filled(64, 7))
      .replaceAll('=', '');
  late SignedQrParser parser;

  setUp(() {
    parser = const SignedQrParser(knownKeyIds: {keyId});
  });

  String uri({
    String scheme = 'io.mqjourney',
    String host = 'open-day',
    String path = '/location/wallys-1',
    String? query,
  }) => '$scheme://$host$path?${query ?? 'v=1&kid=$keyId&sig=$signature'}';

  test('accepts the canonical payload shape', () {
    final result = parser.parse(uri());

    expect(result, isA<ParsedSignedQr>());
    final payload = (result as ParsedSignedQr).payload;
    expect(payload.version, '1');
    expect(payload.keyId, keyId);
    expect(payload.locationId, 'wallys-1');
    expect(payload.signatureBytes, hasLength(64));
  });

  final cases = <String, (String, QrRejectReason)>{
    'wrong scheme': (uri(scheme: 'https'), QrRejectReason.unsupportedScheme),
    'wrong host': (uri(host: 'example.com'), QrRejectReason.unsupportedHost),
    'wrong path': (uri(path: '/place/wallys-1'), QrRejectReason.invalidPath),
    'duplicate key': (
      uri(query: 'v=1&kid=$keyId&sig=$signature&sig=$signature'),
      QrRejectReason.duplicateQueryKey,
    ),
    'unknown key': (
      uri(query: 'v=1&kid=$keyId&sig=$signature&title=x'),
      QrRejectReason.unknownQueryKey,
    ),
    'wrong version': (
      uri(query: 'v=2&kid=$keyId&sig=$signature'),
      QrRejectReason.unsupportedVersion,
    ),
    'wrong kid': (
      uri(query: 'v=1&kid=unknown&sig=$signature'),
      QrRejectReason.unknownKeyId,
    ),
    'bad slug': (
      uri(path: '/location/WALLYS-1'),
      QrRejectReason.invalidLocationSlug,
    ),
    'encoded slug': (
      uri(path: '/location/wallys%2D1'),
      QrRejectReason.invalidLocationSlug,
    ),
    'padded signature': (
      uri(query: 'v=1&kid=$keyId&sig=$signature='),
      QrRejectReason.invalidSignatureEncoding,
    ),
    'short signature': (
      uri(
        query:
            'v=1&kid=$keyId&sig=${base64Url.encode(List<int>.filled(63, 7)).replaceAll('=', '')}',
      ),
      QrRejectReason.invalidSignatureEncoding,
    ),
  };

  for (final entry in cases.entries) {
    test('rejects ${entry.key}', () {
      final result = parser.parse(entry.value.$1);
      expect(
        result,
        isA<RejectedSignedQr>().having(
          (value) => value.reason,
          'reason',
          entry.value.$2,
        ),
      );
    });
  }

  test('rejects user-info, port, and fragment before parsing fields', () {
    expect(
      (parser.parse(
                'io.mqjourney://user@open-day/location/wallys-1?v=1&kid=$keyId&sig=$signature',
              )
              as RejectedSignedQr)
          .reason,
      QrRejectReason.malformedUri,
    );
    expect(
      (parser.parse(
                'io.mqjourney://open-day:443/location/wallys-1?v=1&kid=$keyId&sig=$signature',
              )
              as RejectedSignedQr)
          .reason,
      QrRejectReason.malformedUri,
    );
    expect(
      (parser.parse('${uri()}#x') as RejectedSignedQr).reason,
      QrRejectReason.malformedUri,
    );
  });
}
