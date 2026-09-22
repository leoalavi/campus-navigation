import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current;

  test('web shell loads the iframe bridge before Flutter starts', () {
    final index = File('${repo.path}/web/index.html').readAsStringSync();
    const bridge =
        'assets/packages/flutter_inappwebview_web/assets/web/web_support.js';

    expect(index, contains(bridge));
    expect(
      index.indexOf(bridge),
      lessThan(index.indexOf('flutter_bootstrap.js')),
    );
    expect(index, contains('noindex, nofollow'));
  });

  test('web launcher icons use the current app icon pipeline', () {
    final pubspec = File('${repo.path}/pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('web:\n    generate: true'));
    expect(pubspec, contains('image_path: "assets/images/app_logo.png"'));

    expect(_pngSize(File('${repo.path}/web/icons/Icon-192.png')), (192, 192));
    expect(_pngSize(File('${repo.path}/web/icons/Icon-512.png')), (512, 512));
    expect(_pngSize(File('${repo.path}/web/icons/Icon-maskable-192.png')), (
      192,
      192,
    ));
    expect(_pngSize(File('${repo.path}/web/icons/Icon-maskable-512.png')), (
      512,
      512,
    ));
  });

  test('indoor viewer exposes a browser-readable render state', () {
    final viewer = File(
      '${repo.path}/assets/web/indoor_viewer.html',
    ).readAsStringSync();

    expect(viewer, contains('data-viewer-state="idle"'));
    expect(viewer, contains("dataset.viewerState = 'ready'"));
    expect(viewer, contains('/assets/assets/data/indoor/'));
  });
}

(int, int) _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  expect(bytes.length, greaterThanOrEqualTo(24));
  expect(bytes.sublist(1, 4), <int>[0x50, 0x4e, 0x47]);

  int readUint32(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  return (readUint32(16), readUint32(20));
}
