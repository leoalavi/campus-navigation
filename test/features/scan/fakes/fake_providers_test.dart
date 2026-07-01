import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/contracts/my_day_entry.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_my_day_api.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_progress_api.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_schedule_provider.dart';

void main() {
  group('Fakes', () {
    test('FakeMyDayApi records entries', () async {
      final api = FakeMyDayApi();
      await api.addToDay(
        MyDayEntry(locationId: 'lib-01', when: DateTime.now()),
      );
      expect(api.added.length, 1);
    });

    test(
      'FakeProgressApi returns true on first visit, false on repeat',
      () async {
        final api = FakeProgressApi();
        final event = VisitEvent(
          locationId: 'lib-01',
          scannedAt: DateTime.now(),
        );
        final first = await api.recordVisit(event);
        final second = await api.recordVisit(event);
        expect(first, isTrue);
        expect(second, isFalse);
        expect(api.watch('lib-01'), emits(isA<VisitedState>()));
        api.dispose();
      },
    );

    test('FakeScheduleProvider returns coming up next', () {
      final provider = FakeScheduleProvider();
      expect(provider.liveNow('lib-01'), isNull);
      expect(provider.comingUpNext('lib-01'), isNotNull);
    });
  });
}
