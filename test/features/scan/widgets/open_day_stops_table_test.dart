import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/domain/contracts/schedule_provider.dart';
import 'package:mq_journey/features/scan/domain/contracts/schedule_slot.dart';
import 'package:mq_journey/features/scan/presentation/widgets/open_day_stops_table.dart';

class _NoSchedule implements ScheduleProvider {
  @override
  ScheduleSlot? liveNow(String id) => null;
  @override
  ScheduleSlot? comingUpNext(String id) => null;
}

void main() {
  testWidgets('renders rows in order and reports taps', (tester) async {
    OpenDayStop? tapped;
    const stops = [
      OpenDayStop(stopId: 'a', title: 'Theatre G03', arSceneId: 'g03'),
      OpenDayStop(stopId: 'b', title: 'Theatre 102', arSceneId: '102'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenDayStopsTable(
            stops: stops,
            schedule: _NoSchedule(),
            onTapStop: (s) => tapped = s,
          ),
        ),
      ),
    );
    expect(find.text('Theatre G03'), findsOneWidget);
    expect(find.text('Theatre 102'), findsOneWidget);
    await tester.tap(find.text('Theatre G03'));
    expect(tapped?.stopId, 'a');
  });

  testWidgets('collapses to nothing when empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenDayStopsTable(
            stops: const [],
            schedule: _NoSchedule(),
            onTapStop: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(ListTile), findsNothing);
  });
}
