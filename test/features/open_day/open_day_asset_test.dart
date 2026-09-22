import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/features/open_day/domain/entities/open_day_data.dart';

void main() {
  test('Open Day asset consistently uses Saturday 14 August 2027', () {
    final json =
        jsonDecode(File('assets/data/open_day.json').readAsStringSync())
            as Map<String, dynamic>;
    final data = OpenDayData.fromJson(json);
    final expectedDate = DateTime(2027, 8, 14);

    expect(data.openDayDate, expectedDate);
    expect(data.openDayDate.weekday, DateTime.saturday);
    expect(data.events, isNotEmpty);
    expect(
      data.events.every(
        (event) =>
            event.startTime.year == expectedDate.year &&
            event.startTime.month == expectedDate.month &&
            event.startTime.day == expectedDate.day &&
            event.endTime.year == expectedDate.year &&
            event.endTime.month == expectedDate.month &&
            event.endTime.day == expectedDate.day,
      ),
      isTrue,
    );
  });
}
