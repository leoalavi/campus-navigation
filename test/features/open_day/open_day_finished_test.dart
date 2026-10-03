import 'package:flutter_test/flutter_test.dart';
import 'package:campus_navigation/features/open_day/domain/entities/open_day_data.dart';
import 'package:campus_navigation/features/open_day/presentation/widgets/open_day_home_card.dart';

/// After the last session ends, Home says the Open Day has finished instead
/// of previewing last event's sessions as if they were upcoming.
void main() {
  OpenDayEvent session(DateTime start) => OpenDayEvent(
    id: 'e-${start.hour}',
    title: 'Session',
    startTime: start,
    endTime: start.add(const Duration(minutes: 45)),
    venueName: 'Venue',
    bachelorIds: const [],
  );

  final data = OpenDayData(
    openDayDate: DateTime(2026, 8, 15),
    lastUpdated: DateTime(2026, 6, 29),
    studyAreas: const [],
    bachelors: const [],
    events: [
      session(DateTime(2026, 8, 15, 10)),
      session(DateTime(2026, 8, 15, 14)),
    ],
  );

  test('not over before or during the day', () {
    expect(isOpenDayOver(data, DateTime(2026, 8, 1)), isFalse);
    expect(isOpenDayOver(data, DateTime(2026, 8, 15, 14, 30)), isFalse);
  });

  test('over once the last session has ended', () {
    expect(isOpenDayOver(data, DateTime(2026, 8, 15, 14, 46)), isTrue);
    expect(isOpenDayOver(data, DateTime(2026, 10, 3)), isTrue);
  });

  test('with no sessions, the day itself is the boundary', () {
    final empty = OpenDayData(
      openDayDate: DateTime(2026, 8, 15),
      lastUpdated: DateTime(2026, 6, 29),
      studyAreas: const [],
      bachelors: const [],
      events: const [],
    );
    expect(isOpenDayOver(empty, DateTime(2026, 8, 15, 12)), isFalse);
    expect(isOpenDayOver(empty, DateTime(2026, 8, 17)), isTrue);
  });
}
