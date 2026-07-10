import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/open_day_qr/signing_key_validation.dart';

void main() {
  const registry = <String, List<int>>{
    'mqj-open-day-2026-02': <int>[1, 2, 3, 4],
  };

  test(
    'issuer rejects a public key that does not match the selected key id',
    () {
      expect(
        () => requireSigningKeyMatch(
          keyId: 'mqj-open-day-2026-02',
          actualPublicKey: const <int>[1, 2, 3, 5],
          publicKeys: registry,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'SIGNING_KEY_MISMATCH',
          ),
        ),
      );
    },
  );

  test('issuer rejects an unregistered key id', () {
    expect(
      () => requireSigningKeyMatch(
        keyId: 'unknown',
        actualPublicKey: const <int>[1, 2, 3, 4],
        publicKeys: registry,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'UNKNOWN_SIGNING_KEY_ID',
        ),
      ),
    );
  });

  test('issuer returns the public fingerprint for an exact match', () {
    expect(
      requireSigningKeyMatch(
        keyId: 'mqj-open-day-2026-02',
        actualPublicKey: const <int>[1, 2, 3, 4],
        publicKeys: registry,
      ),
      '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
    );
  });
}
