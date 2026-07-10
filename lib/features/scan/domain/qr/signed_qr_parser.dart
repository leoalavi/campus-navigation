import 'dart:convert';

import 'package:mq_journey/features/scan/domain/qr/qr_validation_result.dart';
import 'package:mq_journey/features/scan/domain/qr/signed_qr_payload.dart';

class SignedQrParser {
  const SignedQrParser({required this.knownKeyIds});

  final Set<String> knownKeyIds;

  static final RegExp _slugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
  static final RegExp _signaturePattern = RegExp(r'^[A-Za-z0-9_-]+$');
  static const Set<String> _queryKeys = {'v', 'kid', 'sig'};

  SignedQrParseResult parse(String raw) {
    try {
      final uri = Uri.tryParse(raw);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        return const RejectedSignedQr(QrRejectReason.malformedUri);
      }
      if (uri.scheme != 'io.mqjourney') {
        return const RejectedSignedQr(QrRejectReason.unsupportedScheme);
      }
      if (uri.host != 'open-day') {
        return const RejectedSignedQr(QrRejectReason.unsupportedHost);
      }
      if (uri.userInfo.isNotEmpty || uri.hasPort || uri.hasFragment) {
        return const RejectedSignedQr(QrRejectReason.malformedUri);
      }

      final rawPath = _rawPath(raw);
      if (uri.pathSegments.length != 2 ||
          uri.pathSegments.first != 'location') {
        return const RejectedSignedQr(QrRejectReason.invalidPath);
      }
      final locationId = uri.pathSegments.last;
      if (rawPath.contains('%') || !_slugPattern.hasMatch(locationId)) {
        return const RejectedSignedQr(QrRejectReason.invalidLocationSlug);
      }

      final queryResult = _parseQuery(uri.query);
      if (queryResult case RejectedSignedQr()) return queryResult;
      final fields = queryResult as _ParsedQuery;

      if (fields.values['v'] != '1') {
        return const RejectedSignedQr(QrRejectReason.unsupportedVersion);
      }
      final keyId = fields.values['kid']!;
      if (!knownKeyIds.contains(keyId)) {
        return const RejectedSignedQr(QrRejectReason.unknownKeyId);
      }

      final encodedSignature = fields.values['sig']!;
      if (!_signaturePattern.hasMatch(encodedSignature) ||
          encodedSignature.contains('=')) {
        return const RejectedSignedQr(QrRejectReason.invalidSignatureEncoding);
      }
      final signatureBytes = base64Url.decode(
        base64Url.normalize(encodedSignature),
      );
      if (signatureBytes.length != 64) {
        return const RejectedSignedQr(QrRejectReason.invalidSignatureEncoding);
      }

      return ParsedSignedQr(
        SignedQrPayload(
          version: '1',
          keyId: keyId,
          locationId: locationId,
          signatureBytes: signatureBytes,
        ),
      );
    } on FormatException {
      return const RejectedSignedQr(QrRejectReason.malformedUri);
    } catch (_) {
      return const RejectedSignedQr(QrRejectReason.internalFailClosed);
    }
  }

  Object _parseQuery(String rawQuery) {
    if (rawQuery.isEmpty) {
      return const RejectedSignedQr(QrRejectReason.unknownQueryKey);
    }
    final values = <String, String>{};
    for (final part in rawQuery.split('&')) {
      final equals = part.indexOf('=');
      if (equals <= 0) {
        return const RejectedSignedQr(QrRejectReason.unknownQueryKey);
      }
      final key = Uri.decodeQueryComponent(part.substring(0, equals));
      final value = Uri.decodeQueryComponent(part.substring(equals + 1));
      if (values.containsKey(key)) {
        return const RejectedSignedQr(QrRejectReason.duplicateQueryKey);
      }
      if (!_queryKeys.contains(key)) {
        return const RejectedSignedQr(QrRejectReason.unknownQueryKey);
      }
      values[key] = value;
    }
    if (values.length != _queryKeys.length ||
        !values.keys.toSet().containsAll(_queryKeys)) {
      return const RejectedSignedQr(QrRejectReason.unknownQueryKey);
    }
    return _ParsedQuery(values);
  }

  String _rawPath(String raw) {
    final authorityStart = raw.indexOf('://') + 3;
    final pathStart = raw.indexOf('/', authorityStart);
    final queryStart = raw.indexOf('?', pathStart);
    if (pathStart < authorityStart || queryStart < pathStart) return '';
    return raw.substring(pathStart, queryStart);
  }
}

class _ParsedQuery {
  const _ParsedQuery(this.values);

  final Map<String, String> values;
}
