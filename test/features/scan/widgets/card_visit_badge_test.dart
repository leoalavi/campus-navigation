import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/presentation/widgets/card_visit_badge.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders nothing when the location has not been visited', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const CardVisitBadge(
          state: VisitedState(visited: false, rewardEarned: false),
        ),
      ),
    );

    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('shows "Visited" when visited without a reward', (tester) async {
    await tester.pumpWidget(
      _app(
        const CardVisitBadge(
          state: VisitedState(visited: true, rewardEarned: false),
        ),
      ),
    );

    expect(find.text('Visited'), findsOneWidget);
  });

  testWidgets('shows "Badge earned!" when visited with a reward', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const CardVisitBadge(
          state: VisitedState(visited: true, rewardEarned: true),
        ),
      ),
    );

    expect(find.text('Badge earned!'), findsOneWidget);
  });
}
