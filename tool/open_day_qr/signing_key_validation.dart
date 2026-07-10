import 'package:crypto/crypto.dart';

String requireSigningKeyMatch({
  required String keyId,
  required List<int> actualPublicKey,
  required Map<String, List<int>> publicKeys,
}) {
  final expectedPublicKey = publicKeys[keyId];
  if (expectedPublicKey == null) {
    throw StateError('UNKNOWN_SIGNING_KEY_ID');
  }
  if (!_bytesEqual(actualPublicKey, expectedPublicKey)) {
    throw StateError('SIGNING_KEY_MISMATCH');
  }
  return sha256.convert(actualPublicKey).toString();
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
