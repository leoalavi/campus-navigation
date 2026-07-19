import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/shared/widgets/glass_pane.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';

void main() {
  testWidgets('GlassPane renders a control-tier GlassSurface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlassPane(
            isDark: false,
            child: const SizedBox(width: 80, height: 30),
          ),
        ),
      ),
    );
    expect(find.byType(GlassSurface), findsOneWidget);
    final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
    expect(surface.variant, GlassVariant.control);
  });
}
