import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trail and stamp catalogues equal the ordered nine-location census', () {
    final trail = jsonDecode(
      File('assets/data/open_day_trail.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final stamps = jsonDecode(
      File('assets/data/open_day_stamps_catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final trailLocations = (trail['locations'] as List)
        .cast<Map<String, dynamic>>()
        .map((entry) => (entry['locationId'], entry['title']))
        .toList(growable: false);
    final stampLocations = (stamps['stamps'] as List)
        .cast<Map<String, dynamic>>()
        .map((entry) => (entry['locationId'], entry['title']))
        .toList(growable: false);

    const expected = <(String, String)>[
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

    expect(trailLocations, expected);
    expect(stampLocations, expected);
  });
}
