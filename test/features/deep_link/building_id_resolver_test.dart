import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/features/deep_link/building_id_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final resolver = BuildingIdResolver();

  test('resolves a canonical id unchanged', () async {
    expect(await resolver.resolve('17WW'), '17WW');
    expect(await resolver.resolve('14SCO'), '14SCO');
  });

  test('resolves case-insensitively', () async {
    expect(await resolver.resolve('17ww'), '17WW');
    expect(await resolver.resolve('  1cc  '), '1CC');
  });

  // The integration case: ids Syllabus Sync holds that this app names
  // differently. Without these, "Navigate" from Syllabus Sync dead-ends.
  test('resolves Syllabus Sync partner ids', () async {
    const expected = {
      '1WW': 'AINS',
      '21WW': 'MQTH',
      '27WW': 'LOTUS',
      '5GR': 'OBS',
      '10GR': 'SPORT',
      '18WWSERVIC': '18WW',
      'MACQUARIEU': 'HOSP',
      'EAST2': 'PEAST2',
    };
    for (final e in expected.entries) {
      expect(await resolver.resolve(e.key), e.value, reason: e.key);
    }
  });

  test('returns null for unknown, empty and future ids', () async {
    for (final id in const [
      '',
      '   ',
      'NOT_A_BUILDING',
      'ZZ99',
      'LAKESIDEHO',
    ]) {
      expect(await resolver.resolve(id), isNull, reason: '"$id"');
    }
  });

  test('every alias points at a building that actually exists', () async {
    // Guards against an alias table that drifts from buildings.json.
    const sample = [
      '1WW',
      '21WW',
      '27WW',
      '16MW',
      '3SR',
      '8LR',
      'CHAP',
      'BIKEHUB',
    ];
    for (final id in sample) {
      final r = await resolver.resolve(id);
      expect(r, isNotNull, reason: id);
      expect(
        await resolver.resolve(r!),
        r,
        reason: '$id -> $r must be canonical',
      );
    }
  });
}
