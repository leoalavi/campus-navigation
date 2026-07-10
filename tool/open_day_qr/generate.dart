import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_canonical_message.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_public_key_registry.dart';

import 'canonical_payload.dart';
import 'signing_key_validation.dart';
import 'svg_renderer.dart';

const expectedCensus = <(String, String)>[
  ('hadenfeld-10', '10 Hadenfeld Avenue'),
  ('wallys-29', "29 Wally's Walk"),
  ('wallys-27', "27 Wally's Walk"),
  ('wallys-23', "23 Wally's Walk"),
  ('wallys-21', "21 Wally's Walk"),
  ('wallys-17', "17 Wally's Walk"),
  ('ondaatje-14', '14 Sir Christopher Ondaatje Avenue'),
  ('wallys-1', "1 Wally's Walk"),
  ('wallys-25', "25 Wally's Walk"),
];

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseOptions(arguments);
    final keyPath = Platform.environment['MQJ_QR_SIGNING_KEY_FILE'];
    if (keyPath == null || keyPath.trim().isEmpty) {
      throw StateError('MQJ_QR_SIGNING_KEY_FILE is required');
    }
    _requireExternalKeyPath(keyPath);

    final trail = _readJson(options['trail']!);
    final stamps = _readJson(options['stamps']!);
    final locations = validateCensus(trail: trail, stamps: stamps);
    final seed = _readEd25519Seed(File(keyPath));
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    final publicFingerprint = requireSigningKeyMatch(
      keyId: options['key-id']!,
      actualPublicKey: publicKey.bytes,
      publicKeys: qrPublicKeys,
    );
    stdout.writeln(
      'keyId=${options['key-id']} '
      'publicSha256=$publicFingerprint MATCH',
    );
    final output = Directory(options['out']!);
    await output.create(recursive: true);
    final manifestLocations = <Map<String, Object>>[];

    for (final location in locations) {
      final locationId = location['locationId']! as String;
      final title = location['title']! as String;
      final signature = await algorithm.sign(
        canonicalQrMessage(
          version: '1',
          keyId: options['key-id']!,
          locationId: locationId,
        ),
        keyPair: keyPair,
      );
      final uri = buildSignedQrUri(
        version: '1',
        keyId: options['key-id']!,
        locationId: locationId,
        signatureBytes: signature.bytes,
      );
      final svg = renderQrSvg(uri);
      final filename = '$locationId.svg';
      await File('${output.path}/$filename').writeAsString(svg, flush: true);
      manifestLocations.add({
        'locationId': locationId,
        'title': title,
        'file': filename,
        'uri': uri,
        'payloadSha256': sha256.convert(utf8.encode(uri)).toString(),
        'svgSha256': sha256.convert(utf8.encode(svg)).toString(),
      });
    }

    final manifest = <String, Object>{
      'schema': 'mqjourney.open-day.qr-manifest.v1',
      'keyId': options['key-id']!,
      'count': manifestLocations.length,
      'locations': manifestLocations,
    };
    final encoded = '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
    await File(
      '${output.path}/manifest.json',
    ).writeAsString(encoded, flush: true);
    if (keyPair is SimpleKeyPairData) keyPair.destroy();
  } on Object catch (error) {
    stderr.writeln('QR generation failed: $error');
    exitCode = 1;
  }
}

List<Map<String, Object?>> validateCensus({
  required Map<String, dynamic> trail,
  required Map<String, dynamic> stamps,
}) {
  final trailLocations = (trail['locations'] as List?)
      ?.cast<Map<String, dynamic>>();
  final stampLocations = (stamps['stamps'] as List?)
      ?.cast<Map<String, dynamic>>();
  if (trailLocations == null || stampLocations == null) {
    throw const FormatException('trail and stamp location arrays are required');
  }
  if (trailLocations.length != expectedCensus.length ||
      stampLocations.length != expectedCensus.length) {
    throw const FormatException('location census must contain exactly nine');
  }

  final seen = <String>{};
  for (var index = 0; index < expectedCensus.length; index++) {
    final expected = expectedCensus[index];
    final trailEntry = trailLocations[index];
    final stampEntry = stampLocations[index];
    final id = trailEntry['locationId'];
    if (id != expected.$1 ||
        stampEntry['locationId'] != expected.$1 ||
        trailEntry['title'] != expected.$2 ||
        stampEntry['title'] != expected.$2 ||
        !seen.add(expected.$1)) {
      throw FormatException('census mismatch at index $index');
    }
    final stampAsset = stampEntry['stampAsset'];
    if (stampAsset is! String || !File(stampAsset).existsSync()) {
      throw FormatException('missing stamp asset for ${expected.$1}');
    }
  }
  return trailLocations.cast<Map<String, Object?>>();
}

Map<String, String> _parseOptions(List<String> arguments) {
  final options = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length || !arguments[index].startsWith('--')) {
      throw const FormatException('options require --name value pairs');
    }
    options[arguments[index].substring(2)] = arguments[index + 1];
  }
  for (final required in ['trail', 'stamps', 'key-id', 'out']) {
    if (options[required]?.isNotEmpty != true) {
      throw FormatException('--$required is required');
    }
  }
  return options;
}

Map<String, dynamic> _readJson(String path) {
  try {
    return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  } on Object catch (error) {
    throw FormatException('unable to read $path: $error');
  }
}

void _requireExternalKeyPath(String path) {
  final repository = Directory.current.absolute.path;
  final key = File(path).absolute.path;
  if (key == repository ||
      key.startsWith('$repository${Platform.pathSeparator}')) {
    throw StateError('the signing key must be stored outside the repository');
  }
}

List<int> _readEd25519Seed(File file) {
  try {
    final bytes = file.readAsBytesSync();
    if (bytes.length == 32) return bytes;
    final text = utf8.decode(bytes);
    const begin = '-----BEGIN PRIVATE KEY-----';
    const end = '-----END PRIVATE KEY-----';
    if (!text.contains(begin) || !text.contains(end)) {
      throw const FormatException('expected raw 32-byte seed or PKCS#8 PEM');
    }
    final encoded = text
        .substring(text.indexOf(begin) + begin.length, text.indexOf(end))
        .replaceAll(RegExp(r'\s'), '');
    final der = base64.decode(encoded);
    const prefix = <int>[
      0x30,
      0x2e,
      0x02,
      0x01,
      0x00,
      0x30,
      0x05,
      0x06,
      0x03,
      0x2b,
      0x65,
      0x70,
      0x04,
      0x22,
      0x04,
      0x20,
    ];
    if (der.length != 48) {
      throw const FormatException('unsupported Ed25519 PKCS#8 encoding');
    }
    for (var index = 0; index < prefix.length; index++) {
      if (der[index] != prefix[index]) {
        throw const FormatException('unsupported Ed25519 PKCS#8 encoding');
      }
    }
    return der.sublist(16);
  } on FileSystemException catch (error) {
    throw StateError('unable to read signing key: ${error.message}');
  }
}
