import 'package:cryptography/cryptography.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_canonical_message.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_validation_result.dart';
import 'package:mq_journey/features/scan/domain/qr/signed_qr_parser.dart';

class QrSignatureVerifier {
  QrSignatureVerifier({required Map<String, List<int>> publicKeys})
    : _publicKeys = Map.unmodifiable(publicKeys),
      _parser = SignedQrParser(knownKeyIds: publicKeys.keys.toSet());

  final Map<String, List<int>> _publicKeys;
  final SignedQrParser _parser;
  final Ed25519 _algorithm = Ed25519();

  Future<QrValidationResult> validate(
    String raw, {
    required bool Function(String locationId) isAllowlisted,
  }) async {
    try {
      final parsed = _parser.parse(raw);
      if (parsed case RejectedSignedQr(:final reason)) {
        return InvalidTrailQr(reason);
      }
      final payload = (parsed as ParsedSignedQr).payload;
      final publicKeyBytes = _publicKeys[payload.keyId];
      if (publicKeyBytes == null) {
        return const InvalidTrailQr(QrRejectReason.unknownKeyId);
      }

      final signature = Signature(
        payload.signatureBytes,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
      );
      final verified = await _algorithm.verify(
        canonicalQrMessage(
          version: payload.version,
          keyId: payload.keyId,
          locationId: payload.locationId,
        ),
        signature: signature,
      );
      if (!verified) {
        return const InvalidTrailQr(QrRejectReason.signatureMismatch);
      }
      if (!isAllowlisted(payload.locationId)) {
        return const InvalidTrailQr(QrRejectReason.locationNotOnTrail);
      }
      return ValidTrailQr(payload.locationId, payload.keyId);
    } catch (_) {
      return const InvalidTrailQr(QrRejectReason.internalFailClosed);
    }
  }
}
