import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/features/timetable/data/repositories/timetable_repository.dart';
import 'package:mq_journey/features/timetable/domain/entities/timetable_class.dart';

final timetableClassesProvider = FutureProvider<List<TimetableClass>>((ref) {
  return ref.watch(timetableRepositoryProvider).loadClasses();
});

/// Injectable clock so the "next class today" cutoff is deterministic in
/// tests (same pattern as `openDayNowProvider`). Production reads the wall
/// clock.
final timetableNowProvider = Provider<DateTime>((ref) => DateTime.now());

final nextTimetableClassProvider = FutureProvider<TimetableClass?>((ref) async {
  final classes = await ref.watch(timetableClassesProvider.future);
  final now = ref.watch(timetableNowProvider);
  final today = classes.where((item) {
    final local = item.startTime;
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  });
  final upcoming = today.where((item) => item.startTime.isAfter(now)).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  return upcoming.isEmpty ? null : upcoming.first;
});
