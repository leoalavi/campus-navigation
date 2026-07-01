import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/timetable/domain/entities/timetable_class.dart';

void main() {
  group('TimetableClass', () {
    test('toJson/fromJson round-trips all fields', () {
      const original = TimetableClass(
        location: 'C3A',
        name: 'COMP3130 Lecture',
        startIso: '2026-08-10T09:00:00.000',
      );

      final json = original.toJson();
      final restored = TimetableClass.fromJson(json);

      expect(restored.location, 'C3A');
      expect(restored.name, 'COMP3130 Lecture');
      expect(restored.startIso, '2026-08-10T09:00:00.000');
    });

    test('fromJson defaults location and name to empty string when missing', () {
      final restored = TimetableClass.fromJson(const {});

      expect(restored.location, '');
      expect(restored.name, '');
    });

    test('fromJson defaults startIso to now when missing', () {
      final before = DateTime.now();
      final restored = TimetableClass.fromJson(const {});
      final after = DateTime.now();

      final parsed = DateTime.parse(restored.startIso);
      expect(
        parsed.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(parsed.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('startTime parses the ISO string to a local DateTime', () {
      const item = TimetableClass(
        location: 'C3A',
        name: 'Lecture',
        startIso: '2026-08-10T09:00:00.000Z',
      );

      expect(item.startTime, DateTime.parse('2026-08-10T09:00:00.000Z').toLocal());
    });
  });
}
