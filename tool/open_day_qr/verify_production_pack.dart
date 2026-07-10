import 'dart:convert';
import 'dart:io';

import 'package:mq_journey/features/scan/domain/qr/qr_public_key_registry.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_signature_verifier.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_validation_result.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln('usage: verify_production_pack.dart PACK TRAIL');
    exitCode = 64;
    return;
  }
  final pack = Directory(arguments[0]);
  final payloadDocument = _readJson('${pack.path}/payloads.json');
  final trail = _readJson(arguments[1]);
  final allowlist = (trail['locations'] as List)
      .cast<Map<String, dynamic>>()
      .map((entry) => entry['locationId']! as String)
      .toSet();
  final verifier = QrSignatureVerifier(publicKeys: qrPublicKeys);
  final positives = <Map<String, Object>>[];
  var allPassed = true;

  for (final entry
      in (payloadDocument['payloads'] as List).cast<Map<String, dynamic>>()) {
    final uri = entry['uri']! as String;
    final locationId = entry['locationId']! as String;
    final result = await verifier.validate(
      uri,
      isAllowlisted: allowlist.contains,
    );
    final accepted = result is ValidTrailQr && result.locationId == locationId;
    allPassed = allPassed && accepted;
    positives.add({
      'locationId': locationId,
      'accepted': accepted,
      'keyId': result is ValidTrailQr ? result.keyId : 'rejected',
    });
  }

  final sample =
      ((payloadDocument['payloads'] as List).first
              as Map<String, dynamic>)['uri']!
          as String;
  final signature = Uri.parse(sample).queryParameters['sig']!;
  final mutatedSignature =
      '${signature.substring(0, signature.length - 1)}'
      '${signature.endsWith('A') ? 'B' : 'A'}';
  final controls = <String, String>{
    'locationMutation': sample.replaceFirst('hadenfeld-10', 'hadenfeld-11'),
    'keyIdMutation': sample.replaceFirst(
      'mqj-open-day-2026-02',
      'mqj-open-day-2026-99',
    ),
    'versionMutation': sample.replaceFirst('v=1', 'v=2'),
    'signatureMutation': sample.replaceFirst(signature, mutatedSignature),
    'duplicateSignature': '$sample&sig=$signature',
    'signedUnknownLocation':
        'io.mqjourney://open-day/location/off-trail?v=1&kid=mqj-open-day-2026-01&sig=-fH5ZT0VMCQl4XH0o_zPY9ojvAjLlz3Y3rx0JGZPZM9YaWYXzobFFtMOA8UtKjGbGzZHPqkwRCfP52jFGqgpBA',
  };
  final negativeResults = <Map<String, String>>[];
  for (final control in controls.entries) {
    final result = await verifier.validate(
      control.value,
      isAllowlisted: allowlist.contains,
    );
    final reason = result is InvalidTrailQr
        ? result.reason.name
        : 'unexpectedAcceptance';
    allPassed = allPassed && result is InvalidTrailQr;
    negativeResults.add({'control': control.key, 'result': reason});
  }

  final report = <String, Object>{
    'schema': 'mqjourney.open-day.qr-signature-report.v1',
    'keyId': payloadDocument['keyId']! as String,
    'positives': positives,
    'negativeControls': negativeResults,
    'allPassed': allPassed,
  };
  final output = File('${pack.path}/qa/signature-report.json');
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    flush: true,
  );
  if (!allPassed) exitCode = 1;
}

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}
