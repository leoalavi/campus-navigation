import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/features/timetable/domain/entities/timetable_class.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _timetableClassesKey = 'timetable.classes';

abstract interface class TimetableRepository {
  Future<List<TimetableClass>> loadClasses();
  Future<void> saveClasses(List<TimetableClass> classes);
}

final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  return SharedPrefsTimetableRepository();
});

class SharedPrefsTimetableRepository implements TimetableRepository {
  @override
  Future<List<TimetableClass>> loadClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timetableClassesKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(TimetableClass.fromJson)
        .toList();
  }

  @override
  Future<void> saveClasses(List<TimetableClass> classes) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(classes.map((value) => value.toJson()).toList());
    await prefs.setString(_timetableClassesKey, payload);
  }
}
