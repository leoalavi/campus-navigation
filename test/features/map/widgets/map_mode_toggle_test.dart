import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_mode_toggle.dart';

void main() {
  testWidgets('renders two segments', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapModeToggle(value: MapMode.campusMap, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.text('Campus Map'), findsOneWidget);
    expect(find.text('AR'), findsOneWidget);
  });

  testWidgets('calls onChanged on segment tap', (tester) async {
    MapMode? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapModeToggle(
            value: MapMode.campusMap,
            onChanged: (mode) => selected = mode,
          ),
        ),
      ),
    );

    await tester.tap(find.text('AR'));
    expect(selected, MapMode.ar);
  });
}
