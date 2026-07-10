import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_canonical_message.dart';

void main() {
  test('canonical message is UTF-8 with frozen field order and final LF', () {
    final bytes = canonicalQrMessage(
      version: '1',
      keyId: 'mqj-open-day-2026-01',
      locationId: 'wallys-1',
    );

    expect(
      utf8.decode(bytes),
      'mqjourney.open-day.qr.v1\n'
      'version=1\n'
      'key_id=mqj-open-day-2026-01\n'
      'location_id=wallys-1\n',
    );
  });
}
