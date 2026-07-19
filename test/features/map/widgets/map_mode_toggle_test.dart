import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_mode_toggle.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';

void main() {
  testWidgets('mode toggle is a control-tier GlassSurface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapModeToggle(value: MapMode.campusMap, onChanged: (_) {}),
        ),
      ),
    );
    final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
    expect(surface.variant, GlassVariant.control);
  });

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
