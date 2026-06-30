import 'package:flutter/material.dart';
import 'package:mq_journey/features/scan/domain/contracts/schedule_provider.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';

class OpenDayStopsTable extends StatelessWidget {
  const OpenDayStopsTable({
    super.key,
    required this.stops,
    required this.schedule,
    required this.onTapStop,
  });

  final List<OpenDayStop> stops;
  final ScheduleProvider schedule;
  final void Function(OpenDayStop stop) onTapStop;

  String? _whatsOn(OpenDayStop stop) {
    final key = stop.scheduleLocationId;
    if (key == null) return null;
    final live = schedule.liveNow(key);
    if (live != null) return 'Live now: ${live.title}';
    final next = schedule.comingUpNext(key);
    if (next != null) return 'Up next: ${next.title}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stop in stops)
          ListTile(
            title: Text(stop.title),
            subtitle: _whatsOn(stop) == null ? null : Text(_whatsOn(stop)!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTapStop(stop),
          ),
      ],
    );
  }
}
