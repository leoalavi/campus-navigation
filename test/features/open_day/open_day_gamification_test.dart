import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_navigation/features/open_day/domain/services/open_day_gamification.dart';

const _trail = <OpenDaySuggestedStop>[
  OpenDaySuggestedStop(
    id: 's1',
    title: 'Computing',
    description: '',
    buildingCode: '4RPD',
  ),
  OpenDaySuggestedStop(
    id: 's2',
    title: 'Engineering',
    description: '',
    buildingCode: '9WW',
  ),
  // A stop without a building code shouldn't count toward the trail total.
  OpenDaySuggestedStop(id: 's3', title: 'No location', description: ''),
];

void main() {
  group('OpenDayGamification.xpForVisitCount', () {
    test('is a flat per-visit amount', () {
      expect(OpenDayGamification.xpForVisitCount(0), 0);
      expect(
        OpenDayGamification.xpForVisitCount(3),
        3 * OpenDayGamification.xpPerVisit,
      );
    });
  });

  group('OpenDayGamification.progress', () {
    test('counts only featured stops with a building code', () {
      final p = OpenDayGamification.progress(
        visited: const ['4RPD'],
        trail: _trail,
        trailName: 'Computing',
      );
      expect(p.totalCount, 2, reason: 's3 has no building code');
      expect(p.visitedCount, 1);
      expect(p.trailComplete, isFalse);
      expect(p.xp, OpenDayGamification.xpPerVisit);
      expect(p.trailName, 'Computing');
    });

    test('is case-insensitive and ignores blanks/duplicates in visits', () {
      final p = OpenDayGamification.progress(
        visited: const ['4rpd', '4RPD', '  ', '9ww'],
        trail: _trail,
      );
      expect(p.visitedCount, 2);
      expect(p.trailComplete, isTrue);
      // Two unique visited codes → 2 × XP (duplicate '4RPD' not double-counted).
      expect(p.xp, 2 * OpenDayGamification.xpPerVisit);
    });

    test('XP counts visits even outside the current trail', () {
      final p = OpenDayGamification.progress(
        visited: const ['4RPD', 'LIB'], // LIB not in this trail
        trail: _trail,
      );
      expect(p.visitedCount, 1, reason: 'only 4RPD is in the trail');
      expect(p.xp, 2 * OpenDayGamification.xpPerVisit);
    });

    test('empty trail reports no progress and is not complete', () {
      final p = OpenDayGamification.progress(
        visited: const [],
        trail: const [],
      );
      expect(p.hasTrail, isFalse);
      expect(p.trailComplete, isFalse);
      expect(p.fraction, 0);
    });
  });
}
