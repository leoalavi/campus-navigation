import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'qr_pipeline_test_support.dart';

void main() {
  test(
    'production QR, trail, stamps and handoff assets equal nine locations',
    () {
      final fixtures = QrPipelineFixtures.load();
      const expected = <(String, String, String)>[
        ('hadenfeld-10', '10 Hadenfeld Avenue', 'P6'),
        ('wallys-29', "29 Wally's Walk", 'L11'),
        ('wallys-27', "27 Wally's Walk", 'L12'),
        ('wallys-23', "23 Wally's Walk", 'L14'),
        ('wallys-21', "21 Wally's Walk", 'L15'),
        ('wallys-17', "17 Wally's Walk", 'L17'),
        ('ondaatje-14', '14 Sir Christopher Ondaatje Avenue', 'J20'),
        ('wallys-1', "1 Wally's Walk", 'K27'),
        ('wallys-25', "25 Wally's Walk", 'N12'),
      ];

      expect(
        fixtures.locations
            .map(
              (fixture) => (
                fixture.location.locationId,
                fixture.location.title,
                fixture.stamp.mapRef,
              ),
            )
            .toList(),
        expected,
      );
      expect(
        fixtures.catalog.map((entry) => entry.locationId).toSet(),
        expected.map((entry) => entry.$1).toSet(),
      );
      expect(
        Directory('QR Codes/SVG Masters').listSync().whereType<File>(),
        hasLength(9),
      );
      expect(
        Directory('QR Codes/PNG 2048px').listSync().whereType<File>(),
        hasLength(9),
      );
      expect(
        Directory('QR Codes/A4 Posters').listSync().whereType<File>(),
        hasLength(9),
      );
    },
  );
}
