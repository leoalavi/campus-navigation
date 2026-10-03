import 'package:flutter_test/flutter_test.dart';
import 'package:campus_navigation/features/scan/data/adapters/open_day_schedule_provider_adapter.dart';
import 'package:campus_navigation/features/open_day/domain/entities/open_day_data.dart';

void main() {
  group('OpenDayScheduleProviderAdapter', () {
    final now = DateTime(2026, 6, 29, 10, 0);
    final events = [
      OpenDayEvent(
        id: 'e1',
        title: 'Library Tour',
        startTime: DateTime(2026, 6, 29, 9, 0),
        endTime: DateTime(2026, 6, 29, 11, 0),
        venueName: 'Library',
        buildingCode: 'C3A',
        bachelorIds: const [],
      ),
    ];

    test('liveNow returns matching slot', () {
      final adapter = OpenDayScheduleProviderAdapter(
        allEvents: events,
        now: now,
      );
      final slot = adapter.liveNow('C3A');
      expect(slot, isNotNull);
      expect(slot!.title, 'Library Tour');
    });

    test('liveNow returns null for non-matching code', () {
      final adapter = OpenDayScheduleProviderAdapter(
        allEvents: events,
        now: now,
      );
      expect(adapter.liveNow('ZZZ'), isNull);
    });

    test('comingUpNext returns null when nothing upcoming', () {
      final adapter = OpenDayScheduleProviderAdapter(
        allEvents: events,
        now: now,
      );
      expect(adapter.comingUpNext('C3A'), isNull);
    });
  });
}
