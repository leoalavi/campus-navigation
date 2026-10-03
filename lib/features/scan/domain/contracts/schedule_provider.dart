import 'package:mq_navigation/features/scan/domain/contracts/schedule_slot.dart';

abstract class ScheduleProvider {
  ScheduleSlot? liveNow(String locationId);
  ScheduleSlot? comingUpNext(String locationId);
}
