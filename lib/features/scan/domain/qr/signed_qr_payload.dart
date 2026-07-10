import 'package:meta/meta.dart';

@immutable
class SignedQrPayload {
  const SignedQrPayload({
    required this.version,
    required this.keyId,
    required this.locationId,
    required this.signatureBytes,
  });

  final String version;
  final String keyId;
  final String locationId;
  final List<int> signatureBytes;
}
