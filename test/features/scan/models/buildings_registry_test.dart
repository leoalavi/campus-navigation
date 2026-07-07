import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/models/buildings_registry.dart';

void main() {
  group('BuildingsRegistry', () {
    const validJson = '''[
      {"code": "C3A", "campusX": 100, "campusY": 200, "entranceLatitude": -33.77, "entranceLongitude": 151.12},
      {"id": "12WW", "campusX": 150, "campusY": 250, "latitude": -33.78, "longitude": 151.13}
    ]''';

    test('parses valid registry with code and id aliases', () {
      final r = BuildingsRegistry.fromJson(validJson);
      expect(r.buildings.length, 2);
      expect(r.buildings[0].code, 'C3A');
      expect(r.buildings[1].code, '12WW');
    });

    test('byCode returns matching building case-insensitively', () {
      final r = BuildingsRegistry.fromJson(validJson);
      expect(r.byCode('c3a')?.code, 'C3A');
      expect(r.byCode('12ww')?.code, '12WW');
    });

    test('byCode returns null for unknown code', () {
      final r = BuildingsRegistry.fromJson(validJson);
      expect(r.byCode('ZZZ'), isNull);
    });

    test('byCode trims input', () {
      final r = BuildingsRegistry.fromJson(validJson);
      expect(r.byCode('  c3a  ')?.code, 'C3A');
    });

    // Regression: the bundled assets/data/buildings.json has 35 of 170
    // entries with no campusX/campusY. The parser used to do an unguarded
    // `(m['campusX'] as num).toDouble()`, so `null as num` threw and the
    // whole registry future errored — which left the AR building picker
    // (`buildingsRegistryProvider`) spinning forever with no visible error.
    test('tolerates entries missing campusX/campusY (defaults to 0)', () {
      const jsonMissingCoords = '''[
        {"code": "A1", "name": "No Coords Building"},
        {"code": "B2", "campusX": 10, "campusY": 20}
      ]''';
      late final BuildingsRegistry r;
      expect(
        () => r = BuildingsRegistry.fromJson(jsonMissingCoords),
        returnsNormally,
      );
      expect(r.buildings.length, 2);
      final a1 = r.byCode('A1')!;
      expect(a1.campusX, 0);
      expect(a1.campusY, 0);
      expect(a1.name, 'No Coords Building');
      expect(r.byCode('B2')!.campusX, 10);
    });
  });
}
