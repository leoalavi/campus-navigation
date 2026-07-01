import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_progress_ring.dart';

void main() {
  testWidgets('renders the collected/total count as text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StampProgressRing(collected: 3, total: 9)),
      ),
    );

    expect(find.text('3/9'), findsOneWidget);
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, closeTo(3 / 9, 0.0001));
  });

  testWidgets('clamps progress to 1.0 when collected exceeds total', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StampProgressRing(collected: 9, total: 9)),
      ),
    );

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, 1.0);
  });
}
