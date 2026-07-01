import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/timetable/data/repositories/timetable_repository.dart';
import 'package:mq_journey/features/timetable/domain/entities/timetable_class.dart';
import 'package:mq_journey/features/timetable/presentation/providers/timetable_provider.dart';

class _FakeTimetableRepository implements TimetableRepository {
  _FakeTimetableRepository(this._classes);
  final List<TimetableClass> _classes;

  @override
  Future<List<TimetableClass>> loadClasses() async => _classes;

  @override
  Future<void> saveClasses(List<TimetableClass> classes) async {}
}

ProviderContainer _containerWith(List<TimetableClass> classes) {
  return ProviderContainer(
    overrides: [
      timetableRepositoryProvider.overrideWithValue(
        _FakeTimetableRepository(classes),
      ),
    ],
  );
}

void main() {
  group('nextTimetableClassProvider', () {
    test('returns the earliest upcoming class today', () async {
      final now = DateTime.now();
      final container = _containerWith([
        TimetableClass(
          location: 'C3A',
          name: 'Later today',
          startIso: now.add(const Duration(hours: 2)).toIso8601String(),
        ),
        TimetableClass(
          location: 'wallys-1',
          name: 'Sooner today',
          startIso: now.add(const Duration(hours: 1)).toIso8601String(),
        ),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(nextTimetableClassProvider.future);

      expect(result?.name, 'Sooner today');
    });

    test('ignores classes that have already started today', () async {
      final now = DateTime.now();
      final container = _containerWith([
        TimetableClass(
          location: 'C3A',
          name: 'Already started',
          startIso: now.subtract(const Duration(minutes: 5)).toIso8601String(),
        ),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(nextTimetableClassProvider.future);

      expect(result, isNull);
    });

    test('ignores classes on a different day', () async {
      final now = DateTime.now();
      final container = _containerWith([
        TimetableClass(
          location: 'C3A',
          name: 'Tomorrow',
          startIso: now.add(const Duration(days: 1)).toIso8601String(),
        ),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(nextTimetableClassProvider.future);

      expect(result, isNull);
    });

    test('returns null when there are no classes at all', () async {
      final container = _containerWith(const []);
      addTearDown(container.dispose);

      final result = await container.read(nextTimetableClassProvider.future);

      expect(result, isNull);
    });
  });
}
