import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/open_day/domain/services/open_day_time.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Golden copy of the official MQ Open Day 2026 "info sessions" grid, taken
/// from the published timetable PDF (16 theatres x 6 start times, 45-minute
/// sessions).
///
/// Each entry is `HH:mm|venue|session title`. This pins every session to the
/// theatre it actually runs in. An earlier revision of the dataset had the
/// 2pm and 3pm rows shifted by one theatre column, which left the schedule
/// internally consistent — right count, real venues, real degrees — while
/// sending people to the wrong lecture theatre. Only a venue-by-venue
/// comparison against the source catches that, so it is spelled out here.
///
/// If the university publishes a revised timetable, update this list in the
/// same commit as `assets/data/open_day.json`.
const _officialSchedule = <String>[
  '10:00|Theatre 1, 10 Hadenfeld Avenue|Bachelor of Media and Communications',
  '10:00|Theatre 1, 29 Wally\'s Walk|Primary teaching',
  '10:00|Lotus Theatre, 27 Wally\'s Walk|Bachelor of Arts',
  '10:00|Price Theatre, 23 Wally\'s Walk|Bachelor of Economics',
  '10:00|Theatre 1, 23 Wally\'s Walk|Bachelor of Professional Accounting',
  '10:00|Theatre 2, 23 Wally\'s Walk|Women in business',
  '10:00|Macquarie Theatre, 21 Wally\'s Walk|Psychology',
  '10:00|Johan van Vloten Theatre (G02), 17 Wally\'s Walk|Critical Indigenous Studies major',
  '10:00|Theatre 2 (G25), 17 Wally\'s Walk|Bachelor of Criminology and Bachelor of Security Studies',
  '10:00|Mason Theatre, 14 Sir Christopher Ondaatje Avenue|Bachelor of Engineering (Honours)',
  '10:00|Theatre 3, 14 Sir Christopher Ondaatje Avenue|Bachelor of Science',
  '10:00|Theatre 4, 14 Sir Christopher Ondaatje Avenue|Bachelor of Cyber Security',
  '10:00|Theatre G03, 1 Wally\'s Walk|Bachelor of Clinical Science and postgraduate pathways, including Doctor of Medicine',
  '11:00|Theatre 1, 29 Wally\'s Walk|Macquarie Entry: Pathways for high school students',
  '11:00|Lotus Theatre, 27 Wally\'s Walk|Bachelor of Business',
  '11:00|Price Theatre, 23 Wally\'s Walk|Bachelor of Exercise and Sports Science',
  '11:00|Theatre 1, 23 Wally\'s Walk|Macquarie Entry: Pathways for non-school applicants',
  '11:00|Theatre 2, 23 Wally\'s Walk|Bachelor of Business Analytics',
  '11:00|Macquarie Theatre, 21 Wally\'s Walk|Bachelor of Laws',
  '11:00|Johan van Vloten Theatre (G02), 17 Wally\'s Walk|Languages and cultures',
  '11:00|Theatre 2 (G25), 17 Wally\'s Walk|Bachelor of Social Sciences',
  '11:00|Mason Theatre, 14 Sir Christopher Ondaatje Avenue|Bachelor of Information Technology',
  '11:00|Theatre 3, 14 Sir Christopher Ondaatje Avenue|Bachelor of Environment',
  '11:00|Theatre G03, 1 Wally\'s Walk|Empowering women in STEMM',
  '11:00|C122 Exhibition Space, 25 Wally\'s Walk|Early childhood teaching',
  '12:00|Theatre 1, 29 Wally\'s Walk|Early entry application workshop',
  '12:00|Lotus Theatre, 27 Wally\'s Walk|Bachelor of Medical Sciences',
  '12:00|Price Theatre, 23 Wally\'s Walk|Speech and hearing sciences',
  '12:00|Theatre 1, 23 Wally\'s Walk|Pathways to a degree through Macquarie University College',
  '12:00|Theatre 2, 23 Wally\'s Walk|Bachelor of Marketing and Media',
  '12:00|Macquarie Theatre, 21 Wally\'s Walk|Bachelor of Commerce',
  '12:00|Theatre 2 (G25), 17 Wally\'s Walk|History and archaeology',
  '12:00|Mason Theatre, 14 Sir Christopher Ondaatje Avenue|Bachelor of Science',
  '12:00|Theatre 3, 14 Sir Christopher Ondaatje Avenue|Bachelor of Health Sciences',
  '12:00|Theatre 4, 14 Sir Christopher Ondaatje Avenue|Bachelor of Game Design and Development',
  '12:00|Theatre G03, 1 Wally\'s Walk|Doctor of Physiotherapy',
  '12:00|Theatre 102, 1 Wally\'s Walk|Master of Public Health',
  '12:00|Theatre 202, 1 Wally\'s Walk|Applying linguistics: Putting language science into practice',
  '12:00|C122 Exhibition Space, 25 Wally\'s Walk|Bachelor of International Studies',
  '13:00|Theatre 1, 10 Hadenfeld Avenue|Bachelor of Media and Communications',
  '13:00|Theatre 1, 29 Wally\'s Walk|Bachelor of Actuarial Studies + Co-op program',
  '13:00|Lotus Theatre, 27 Wally\'s Walk|Bachelor of Laws',
  '13:00|Price Theatre, 23 Wally\'s Walk|Maximise your marks: Pro tips from a senior HSC marker',
  '13:00|Theatre 1, 23 Wally\'s Walk|From high school to higher ed: A parent\'s guide to uni',
  '13:00|Theatre 2, 23 Wally\'s Walk|Get a career advantage with a Macquarie business degree',
  '13:00|Macquarie Theatre, 21 Wally\'s Walk|Psychology',
  '13:00|Johan van Vloten Theatre (G02), 17 Wally\'s Walk|Bachelor of Planning',
  '13:00|Theatre 2 (G25), 17 Wally\'s Walk|Secondary teaching',
  '13:00|Mason Theatre, 14 Sir Christopher Ondaatje Avenue|Bachelor of Engineering (Honours)',
  '13:00|Theatre 3, 14 Sir Christopher Ondaatje Avenue|Bachelor of Biodiversity and Conservation',
  '13:00|Theatre 4, 14 Sir Christopher Ondaatje Avenue|Bachelor of Cyber Security',
  '13:00|Theatre G03, 1 Wally\'s Walk|Bachelor of Clinical Science and postgraduate pathways, including Doctor of Medicine',
  '13:00|C122 Exhibition Space, 25 Wally\'s Walk|Marketing',
  '14:00|Theatre 1, 29 Wally\'s Walk|Bachelor of Arts',
  '14:00|Lotus Theatre, 27 Wally\'s Walk|Bachelor of Commerce',
  '14:00|Price Theatre, 23 Wally\'s Walk|Bachelor of Applied Finance',
  '14:00|Theatre 1, 23 Wally\'s Walk|Pathways to a degree through Macquarie University College',
  '14:00|Theatre 2, 23 Wally\'s Walk|Bachelor of Social Sciences',
  '14:00|Macquarie Theatre, 21 Wally\'s Walk|Early entry application workshop',
  '14:00|Johan van Vloten Theatre (G02), 17 Wally\'s Walk|Languages and cultures',
  '14:00|Theatre 2 (G25), 17 Wally\'s Walk|Bachelor of Security Studies',
  '14:00|Mason Theatre, 14 Sir Christopher Ondaatje Avenue|Bachelor of Science',
  '14:00|Theatre 4, 14 Sir Christopher Ondaatje Avenue|Bachelor of Information Technology',
  '14:00|Theatre G03, 1 Wally\'s Walk|Bachelor of Exercise and Sports Science',
  '14:00|Theatre 102, 1 Wally\'s Walk|Chiropractic science',
  '14:00|C122 Exhibition Space, 25 Wally\'s Walk|History and archaeology',
  '15:00|Theatre 1, 10 Hadenfeld Avenue|Bachelor of Media and Communications',
  '15:00|Theatre 1, 29 Wally\'s Walk|Macquarie Entry: Pathways for high school students',
  '15:00|Lotus Theatre, 27 Wally\'s Walk|Bachelor of Criminology',
  '15:00|Price Theatre, 23 Wally\'s Walk|Maximise your marks: Pro tips from a senior HSC marker',
  '15:00|Theatre 2, 23 Wally\'s Walk|Bachelor of Marketing and Media',
  '15:00|Macquarie Theatre, 21 Wally\'s Walk|Bachelor of Business',
  '15:00|Theatre 2 (G25), 17 Wally\'s Walk|Primary and early childhood teaching',
  '15:00|Mason Theatre, 14 Sir Christopher Ondaatje Avenue|Bachelor of Medical Sciences',
  '15:00|Theatre 3, 14 Sir Christopher Ondaatje Avenue|Bachelor of Information Technology',
  '15:00|Theatre 4, 14 Sir Christopher Ondaatje Avenue|Bachelor of Engineering (Honours)',
  '15:00|Theatre G03, 1 Wally\'s Walk|Bachelor of Health Sciences',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenDayData data;

  setUpAll(() async {
    // Times are compared as Sydney wall-clock, the same way every screen
    // renders them — a device-local `.hour` would read 00:00 under UTC.
    tzdata.initializeTimeZones();
    final raw = await rootBundle.loadString('assets/data/open_day.json');
    data = OpenDayData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  String slot(DateTime instant) {
    final t = OpenDayTime.toSydney(instant);
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  test('every session runs in the theatre the official timetable lists', () {
    final actual = <String>{
      for (final e in data.events)
        '${slot(e.startTime)}|${e.venueName}|${e.title}',
    };
    final expected = _officialSchedule.toSet();

    expect(
      actual.difference(expected),
      isEmpty,
      reason: 'sessions in the app that the official timetable does not list',
    );
    expect(
      expected.difference(actual),
      isEmpty,
      reason: 'sessions the official timetable lists that the app is missing',
    );
  });

  test('the schedule has the official number of sessions', () {
    expect(data.events, hasLength(_officialSchedule.length));
  });

  test('no two sessions are booked into the same theatre at the same time', () {
    final seen = <String>{};
    for (final e in data.events) {
      final key = '${slot(e.startTime)}|${e.venueName}';
      expect(seen.add(key), isTrue, reason: 'double-booked: $key (${e.id})');
    }
  });

  test('sessions start only at the six official times', () {
    const times = {'10:00', '11:00', '12:00', '13:00', '14:00', '15:00'};
    for (final e in data.events) {
      expect(times, contains(slot(e.startTime)), reason: e.id);
    }
  });
}
