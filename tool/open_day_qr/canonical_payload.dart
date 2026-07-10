import 'dart:convert';

String buildSignedQrUri({
  required String version,
  required String keyId,
  required String locationId,
  required List<int> signatureBytes,
}) {
  final signature = base64Url.encode(signatureBytes).replaceAll('=', '');
  return 'io.mqjourney://open-day/location/$locationId'
      '?v=$version&kid=$keyId&sig=$signature';
}
