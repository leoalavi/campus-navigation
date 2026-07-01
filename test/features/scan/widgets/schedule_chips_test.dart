import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/contracts/schedule_slot.dart';
import 'package:mq_journey/features/scan/presentation/widgets/schedule_chips.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

final _slotA = ScheduleSlot(
  title: 'Opening Keynote',
  start: DateTime(2026, 8, 22, 9),
  end: DateTime(2026, 8, 22, 10),
);
final _slotB = ScheduleSlot(
  title: 'Campus Tour',
  start: DateTime(2026, 8, 22, 11),
  end: DateTime(2026, 8, 22, 12),
);

void main() {
  testWidgets('renders nothing when neither slot is set', (tester) async {
    await tester.pumpWidget(_app(const ScheduleChips()));

    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('renders only the live-now chip when only liveNow is set', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ScheduleChips(liveNow: _slotA)));

    expect(find.text('Live Now: Opening Keynote'), findsOneWidget);
    expect(find.textContaining('Up Next:'), findsNothing);
  });

  testWidgets('renders both chips when both slots are set', (tester) async {
    await tester.pumpWidget(
      _app(ScheduleChips(liveNow: _slotA, comingUpNext: _slotB)),
    );

    expect(find.text('Live Now: Opening Keynote'), findsOneWidget);
    expect(find.text('Up Next: Campus Tour'), findsOneWidget);
  });
}
