import 'package:flutter/foundation.dart';

@immutable
class ScheduleSlot {
  final String title;
  final DateTime start;
  final DateTime end;

  const ScheduleSlot({
    required this.title,
    required this.start,
    required this.end,
  });
}
