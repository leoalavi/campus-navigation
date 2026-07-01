import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/timetable/data/repositories/timetable_repository.dart';
import 'package:mq_journey/features/timetable/domain/entities/timetable_class.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPrefsTimetableRepository', () {
    test('loadClasses returns an empty list when nothing is stored', () async {
      final repository = SharedPrefsTimetableRepository();

      final classes = await repository.loadClasses();

      expect(classes, isEmpty);
    });

    test(
      'saveClasses then loadClasses round-trips the stored classes',
      () async {
        final repository = SharedPrefsTimetableRepository();
        const classes = [
          TimetableClass(
            location: 'C3A',
            name: 'COMP3130 Lecture',
            startIso: '2026-08-10T09:00:00.000',
          ),
          TimetableClass(
            location: 'wallys-1',
            name: 'Tutorial',
            startIso: '2026-08-10T11:00:00.000',
          ),
        ];

        await repository.saveClasses(classes);
        final loaded = await repository.loadClasses();

        expect(loaded.length, 2);
        expect(loaded[0].name, 'COMP3130 Lecture');
        expect(loaded[1].name, 'Tutorial');
      },
    );

    test(
      'saveClasses with an empty list clears previously stored classes',
      () async {
        final repository = SharedPrefsTimetableRepository();
        await repository.saveClasses(const [
          TimetableClass(
            location: 'C3A',
            name: 'Lecture',
            startIso: '2026-08-10T09:00:00.000',
          ),
        ]);

        await repository.saveClasses(const []);
        final loaded = await repository.loadClasses();

        expect(loaded, isEmpty);
      },
    );
  });
}
