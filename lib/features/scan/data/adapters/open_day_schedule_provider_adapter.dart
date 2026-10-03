import 'package:mq_navigation/features/scan/domain/contracts/schedule_provider.dart';
import 'package:mq_navigation/features/scan/domain/contracts/schedule_slot.dart';
import 'package:mq_navigation/features/open_day/domain/services/open_day_personalisation.dart';
import 'package:mq_navigation/features/open_day/domain/entities/open_day_data.dart';

class OpenDayScheduleProviderAdapter implements ScheduleProvider {
  OpenDayScheduleProviderAdapter({
    required List<OpenDayEvent> allEvents,
    required DateTime now,
  }) : _allEvents = allEvents,
       _now = now;

  final List<OpenDayEvent> _allEvents;
  final DateTime _now;

  @override
  ScheduleSlot? liveNow(String locationId) {
    final status = OpenDayPersonalisation.liveStatusForLocation(
      _allEvents,
      locationId,
      _now,
    );
    if (status.liveNow.isEmpty) return null;
    final e = status.liveNow.first;
    return ScheduleSlot(title: e.title, start: e.startTime, end: e.endTime);
  }

  @override
  ScheduleSlot? comingUpNext(String locationId) {
    final status = OpenDayPersonalisation.liveStatusForLocation(
      _allEvents,
      locationId,
      _now,
    );
    if (status.comingUpNext == null) return null;
    return ScheduleSlot(
      title: status.comingUpNext!.title,
      start: status.comingUpNext!.startTime,
      end: status.comingUpNext!.endTime,
    );
  }
}
