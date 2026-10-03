import 'package:qr/qr.dart';

String renderQrSvg(String payload, {int quietZoneModules = 4}) {
  if (quietZoneModules < 4) {
    throw ArgumentError.value(
      quietZoneModules,
      'quietZoneModules',
      'must be at least four modules',
    );
  }
  final code = QrCode(
    payload: QrPayload.fromString(payload),
    errorCorrectLevel: QrErrorCorrectLevel.quartile,
  );
  final image = QrImage(code);
  final size = image.moduleCount + (quietZoneModules * 2);
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'viewBox="0 0 $size $size" shape-rendering="crispEdges">',
    )
    ..writeln('<rect width="$size" height="$size" fill="#FFFFFF"/>')
    ..writeln('<g fill="#000000">');
  for (var row = 0; row < image.moduleCount; row++) {
    for (var column = 0; column < image.moduleCount; column++) {
      if (image.isDark(row, column)) {
        buffer.writeln(
          '<rect x="${column + quietZoneModules}" '
          'y="${row + quietZoneModules}" width="1" height="1"/>',
        );
      }
    }
  }
  buffer
    ..writeln('</g>')
    ..writeln('</svg>');
  return buffer.toString();
}
