import 'package:campus_navigation/features/scan/domain/contracts/schedule_provider.dart';
import 'package:campus_navigation/features/scan/domain/contracts/schedule_slot.dart';

class FakeScheduleProvider implements ScheduleProvider {
  @override
  ScheduleSlot? liveNow(String locationId) => null;

  @override
  ScheduleSlot? comingUpNext(String locationId) {
    return ScheduleSlot(
      title: 'Open Day Tour',
      start: DateTime.now().add(const Duration(minutes: 30)),
      end: DateTime.now().add(const Duration(minutes: 60)),
    );
  }
}
