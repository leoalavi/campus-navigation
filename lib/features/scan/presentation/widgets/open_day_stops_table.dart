import 'package:flutter/material.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
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

  String? _whatsOn(BuildContext context, OpenDayStop stop) {
    final key = stop.scheduleLocationId;
    if (key == null) return null;
    final l10n = AppLocalizations.of(context)!;
    final live = schedule.liveNow(key);
    if (live != null) return l10n.stopLiveNow(live.title);
    final next = schedule.comingUpNext(key);
    if (next != null) return l10n.stopUpNext(next.title);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stop in stops)
          Builder(
            builder: (context) {
              final whatsOn = _whatsOn(context, stop);
              return ListTile(
                title: Text(stop.title),
                subtitle: whatsOn == null ? null : Text(whatsOn),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onTapStop(stop),
              );
            },
          ),
      ],
    );
  }
}
