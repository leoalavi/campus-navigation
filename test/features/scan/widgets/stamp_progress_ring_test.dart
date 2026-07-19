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

  testWidgets('track is a light ink in dark mode (was invisible charcoal)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: Center(child: StampProgressRing(collected: 2, total: 9)),
        ),
      ),
    );
    final track = tester
        .widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .backgroundColor;
    // Must be white-based so it reads on the dark scaffold, not a fixed
    // charcoal that vanishes. (computeLuminance ignores alpha, so this checks
    // the underlying ink, which is the regression that mattered.)
    expect(track, isNotNull);
    expect(track!.computeLuminance(), greaterThan(0.5));
  });

  testWidgets('track is a dark ink in light mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: const Scaffold(
          body: Center(child: StampProgressRing(collected: 2, total: 9)),
        ),
      ),
    );
    final track = tester
        .widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .backgroundColor;
    expect(track, isNotNull);
    expect(track!.computeLuminance(), lessThan(0.5));
  });
}
