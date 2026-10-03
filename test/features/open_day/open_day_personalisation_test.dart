import 'package:flutter_test/flutter_test.dart';
import 'package:campus_navigation/features/open_day/domain/entities/open_day_data.dart';
import 'package:campus_navigation/features/open_day/domain/services/open_day_personalisation.dart';

/// Small fixture mirroring the shape of `assets/data/open_day.json` but with
/// just enough rows to exercise the ranking + live-status rules.
OpenDayData _fixture() {
  return OpenDayData(
    openDayDate: DateTime.parse('2026-08-15T00:00:00+10:00'),
    lastUpdated: DateTime.parse('2026-04-29T00:00:00+10:00'),
    studyAreas: const [
      OpenDayStudyArea(
        id: 'fse',
        name: 'Science & Engineering',
        icon: 'science',
      ),
      OpenDayStudyArea(id: 'mbs', name: 'Business', icon: 'business_center'),
    ],
    bachelors: const [
      OpenDayBachelor(id: 'computing', name: 'Computing', studyAreaId: 'fse'),
      OpenDayBachelor(id: 'business', name: 'Commerce', studyAreaId: 'mbs'),
    ],
    events: [
      OpenDayEvent(
        id: 'evt-comp',
        title: 'Computing Info Session',
        startTime: DateTime.parse('2026-08-15T10:00:00+10:00'),
        endTime: DateTime.parse('2026-08-15T10:30:00+10:00'),
        venueName: 'Price Theatre',
        bachelorIds: const ['computing'],
      ),
      OpenDayEvent(
        id: 'evt-biz',
        title: 'Commerce Info Session',
        startTime: DateTime.parse('2026-08-15T11:00:00+10:00'),
        endTime: DateTime.parse('2026-08-15T11:30:00+10:00'),
        venueName: '4 Eastern Road',
        bachelorIds: const ['business'],
      ),
    ],
    suggestedStops: const [
      // Direct bachelor match for computing (score 3).
      OpenDaySuggestedStop(
        id: 'stop-computing',
        title: 'School of Computing',
        description: 'Labs',
        studyAreaIds: ['fse'],
        bachelorIds: ['computing'],
      ),
      // Area-level FSE match (score 2 for computing).
      OpenDaySuggestedStop(
        id: 'stop-science',
        title: 'Science Labs',
        description: 'Science',
        studyAreaIds: ['fse'],
        bachelorIds: ['science'],
      ),
      // Unrelated area (score 0 for computing).
      OpenDaySuggestedStop(
        id: 'stop-business',
        title: 'Business School',
        description: 'Business',
        studyAreaIds: ['mbs'],
        bachelorIds: ['business'],
      ),
      // Universal fallback (score 1 for everyone).
      OpenDaySuggestedStop(
        id: 'stop-library',
        title: 'Library',
        description: 'Study',
      ),
    ],
  );
}

void main() {
  group('OpenDayPersonalisation.suggestedStops', () {
    test('degree-first: exact + universal only, NO faculty siblings', () {
      final data = _fixture();
      final computing = data.bachelorById('computing');

      final result = OpenDayPersonalisation.suggestedStops(data, computing);

      expect(
        result.map((s) => s.id),
        ['stop-computing', 'stop-library'],
        reason:
            'exact degree stop + universal; the same-faculty stop-science '
            'must NOT be pulled in when an exact match exists',
      );
    });

    test(
      'falls back to faculty stops ONLY when the degree has no own stop',
      () {
        final data = _fixture();
        // 'physics' is fse but no stop names it → fallback to fse siblings.
        const physics = OpenDayBachelor(
          id: 'physics',
          name: 'Physics',
          studyAreaId: 'fse',
        );

        final result = OpenDayPersonalisation.suggestedStops(data, physics);

        expect(
          result.map((s) => s.id),
          ['stop-computing', 'stop-science', 'stop-library'],
          reason: 'no exact physics stop → faculty (fse) stops + universal',
        );
      },
    );

    test('with no selection, only universal stops are returned', () {
      final data = _fixture();

      final result = OpenDayPersonalisation.suggestedStops(data, null);

      expect(result.map((s) => s.id), ['stop-library']);
    });

    test('respects the max cap', () {
      final data = _fixture();
      final computing = data.bachelorById('computing');

      final result = OpenDayPersonalisation.suggestedStops(
        data,
        computing,
        max: 1,
      );

      expect(result, hasLength(1));
      expect(result.first.id, 'stop-computing');
    });
  });

  group('OpenDaySuggestedStop.relevanceFor', () {
    test('scores by specificity', () {
      const stop = OpenDaySuggestedStop(
        id: 's',
        title: 't',
        description: 'd',
        studyAreaIds: ['fse'],
        bachelorIds: ['computing'],
      );
      const computing = OpenDayBachelor(
        id: 'computing',
        name: 'C',
        studyAreaId: 'fse',
      );
      const otherFse = OpenDayBachelor(
        id: 'science',
        name: 'S',
        studyAreaId: 'fse',
      );
      const business = OpenDayBachelor(
        id: 'business',
        name: 'B',
        studyAreaId: 'mbs',
      );

      expect(stop.relevanceFor(computing), 3);
      expect(stop.relevanceFor(otherFse), 2);
      expect(stop.relevanceFor(business), 0);
    });

    test('universal stop scores 1 for anyone and for no selection', () {
      const stop = OpenDaySuggestedStop(id: 's', title: 't', description: 'd');
      const business = OpenDayBachelor(
        id: 'business',
        name: 'B',
        studyAreaId: 'mbs',
      );

      expect(stop.relevanceFor(null), 1);
      expect(stop.relevanceFor(business), 1);
    });
  });

  group('OpenDayPersonalisation.liveStatus', () {
    test('reports a live event when now is inside its window', () {
      final data = _fixture();
      final now = DateTime.parse('2026-08-15T10:15:00+10:00');

      final status = OpenDayPersonalisation.liveStatus(
        data.events,
        data.events,
        now,
      );

      expect(status.liveNow.map((e) => e.id), ['evt-comp']);
      expect(status.comingUpNext?.id, 'evt-biz');
      expect(status.usedFallback, isFalse);
    });

    test('reports only coming-up before the day starts', () {
      final data = _fixture();
      final now = DateTime.parse('2026-08-15T09:00:00+10:00');

      final status = OpenDayPersonalisation.liveStatus(
        data.events,
        data.events,
        now,
      );

      expect(status.liveNow, isEmpty);
      expect(status.comingUpNext?.id, 'evt-comp');
    });

    test('falls back to full schedule when relevant list is empty', () {
      final data = _fixture();
      final now = DateTime.parse('2026-08-15T09:00:00+10:00');

      final status = OpenDayPersonalisation.liveStatus(
        const [],
        data.events,
        now,
      );

      expect(status.comingUpNext?.id, 'evt-comp');
      expect(status.usedFallback, isTrue);
    });

    test('is empty after the day is over', () {
      final data = _fixture();
      final now = DateTime.parse('2026-08-15T18:00:00+10:00');

      final status = OpenDayPersonalisation.liveStatus(
        data.events,
        data.events,
        now,
      );

      expect(status.isEmpty, isTrue);
    });
  });

  group('OpenDayPersonalisation.liveStatusForLocation', () {
    test('scopes live/next to a single building code (case-insensitive)', () {
      // Build a small location-scoped set with explicit building codes.
      final events = [
        OpenDayEvent(
          id: 'a',
          title: 'Talk A',
          startTime: DateTime.parse('2026-08-15T10:00:00+10:00'),
          endTime: DateTime.parse('2026-08-15T10:30:00+10:00'),
          venueName: 'Price',
          buildingCode: 'PRICE',
          bachelorIds: const [],
        ),
        OpenDayEvent(
          id: 'b',
          title: 'Talk B',
          startTime: DateTime.parse('2026-08-15T11:00:00+10:00'),
          endTime: DateTime.parse('2026-08-15T11:30:00+10:00'),
          venueName: 'Price',
          buildingCode: 'price',
          bachelorIds: const [],
        ),
        OpenDayEvent(
          id: 'c',
          title: 'Elsewhere',
          startTime: DateTime.parse('2026-08-15T10:05:00+10:00'),
          endTime: DateTime.parse('2026-08-15T10:30:00+10:00'),
          venueName: 'Lotus',
          buildingCode: 'LOTUS',
          bachelorIds: const [],
        ),
      ];
      final now = DateTime.parse('2026-08-15T10:15:00+10:00');

      final status = OpenDayPersonalisation.liveStatusForLocation(
        events,
        'price',
        now,
      );

      expect(status.liveNow.map((e) => e.id), ['a']);
      expect(status.comingUpNext?.id, 'b');
    });

    test('returns empty for a location with no sessions', () {
      final data = _fixture();
      final status = OpenDayPersonalisation.liveStatusForLocation(
        data.events,
        'NOPE',
        DateTime.parse('2026-08-15T10:15:00+10:00'),
      );
      expect(status.isEmpty, isTrue);
    });
  });
}
