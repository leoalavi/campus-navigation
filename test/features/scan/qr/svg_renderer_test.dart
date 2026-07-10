import 'package:flutter_test/flutter_test.dart';
import '../../../../tool/open_day_qr/svg_renderer.dart';

void main() {
  test(
    'SVG rendering is deterministic and includes a four-module quiet zone',
    () {
      final first = renderQrSvg('io.mqjourney://example', quietZoneModules: 4);
      final second = renderQrSvg('io.mqjourney://example', quietZoneModules: 4);

      expect(second, first);
      expect(first, startsWith('<?xml version="1.0" encoding="UTF-8"?>\n'));
      expect(first, contains('fill="#FFFFFF"'));
      expect(first, contains('fill="#000000"'));
      expect(first, endsWith('\n'));
    },
  );
}
