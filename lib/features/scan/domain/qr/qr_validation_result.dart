import 'package:flutter/foundation.dart';
import 'package:mq_journey/features/scan/domain/qr/signed_qr_payload.dart';

enum QrRejectReason {
  malformedUri,
  unsupportedScheme,
  unsupportedHost,
  invalidPath,
  duplicateQueryKey,
  unknownQueryKey,
  unsupportedVersion,
  unknownKeyId,
  invalidLocationSlug,
  invalidSignatureEncoding,
  signatureMismatch,
  locationNotOnTrail,
  internalFailClosed,
}

sealed class SignedQrParseResult {
  const SignedQrParseResult();
}

@immutable
final class ParsedSignedQr extends SignedQrParseResult {
  const ParsedSignedQr(this.payload);

  final SignedQrPayload payload;
}

@immutable
final class RejectedSignedQr extends SignedQrParseResult {
  const RejectedSignedQr(this.reason);

  final QrRejectReason reason;
}

sealed class QrValidationResult {
  const QrValidationResult();
}

@immutable
final class ValidTrailQr extends QrValidationResult {
  const ValidTrailQr(this.locationId, this.keyId);

  final String locationId;
  final String keyId;
}

@immutable
final class InvalidTrailQr extends QrValidationResult {
  const InvalidTrailQr(this.reason);

  final QrRejectReason reason;
}
