import 'package:flutter/foundation.dart';

@immutable
class MyDayEntry {
  final String locationId;
  final DateTime when;

  const MyDayEntry({required this.locationId, required this.when});
}
