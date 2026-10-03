import 'dart:convert';
import 'dart:typed_data';

Uint8List canonicalQrMessage({
  required String version,
  required String keyId,
  required String locationId,
}) {
  final text =
      'mqjourney.open-day.qr.v1\n'
      'version=$version\n'
      'key_id=$keyId\n'
      'location_id=$locationId\n';
  return Uint8List.fromList(utf8.encode(text));
}
