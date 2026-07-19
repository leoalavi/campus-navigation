import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';

Widget _host({
  required Widget child,
  bool highContrast = false,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(
        highContrast: highContrast,
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

bool _hasSolidFill(WidgetTester tester, {double minAlpha = 0.92}) {
  final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
  return boxes.any((box) {
    final d = box.decoration;
    if (d is! BoxDecoration) return false;
    final c = d.color;
    return c != null && c.a >= minAlpha;
  });
}

void main() {
  group('resolveGlassRenderMode', () {
    test('content is always solid', () {
      expect(
        resolveGlassRenderMode(
          variant: GlassVariant.content,
          highContrast: false,
          disableAnimations: false,
          shaderSupported: true,
        ),
        GlassRenderMode.solid,
      );
    });
    test('high contrast forces solid', () {
      expect(
        resolveGlassRenderMode(
          variant: GlassVariant.control,
          highContrast: true,
          disableAnimations: false,
          shaderSupported: true,
        ),
        GlassRenderMode.solid,
      );
    });
    test('reduce motion drops to frost', () {
      expect(
        resolveGlassRenderMode(
          variant: GlassVariant.control,
          highContrast: false,
          disableAnimations: true,
          shaderSupported: true,
        ),
        GlassRenderMode.frost,
      );
    });
    test('no shader support drops to frost', () {
      expect(
        resolveGlassRenderMode(
          variant: GlassVariant.bar,
          highContrast: false,
          disableAnimations: false,
          shaderSupported: false,
        ),
        GlassRenderMode.frost,
      );
    });
    test('supported + no a11y flags -> shader', () {
      expect(
        resolveGlassRenderMode(
          variant: GlassVariant.control,
          highContrast: false,
          disableAnimations: false,
          shaderSupported: true,
        ),
        GlassRenderMode.shader,
      );
    });
  });

  testWidgets('content tier is solid — no BackdropFilter', (tester) async {
    await tester.pumpWidget(
      _host(
        child: const GlassSurface(
          variant: GlassVariant.content,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(_hasSolidFill(tester), isTrue);
  });

  testWidgets('control tier renders frost (no Impeller in tests)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        child: const GlassSurface(
          variant: GlassVariant.control,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('high contrast forces solid for control tier', (tester) async {
    await tester.pumpWidget(
      _host(
        highContrast: true,
        child: const GlassSurface(
          variant: GlassVariant.control,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(_hasSolidFill(tester), isTrue);
  });

  testWidgets('reduce motion keeps frost (still a BackdropFilter)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        disableAnimations: true,
        child: const GlassSurface(
          variant: GlassVariant.control,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('color + border overrides honoured (content)', (tester) async {
    await tester.pumpWidget(
      _host(
        child: const GlassSurface(
          variant: GlassVariant.content,
          color: Color(0xFF00FF00),
          borderColor: Color(0xFF123456),
          borderWidth: 0.6,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );
    final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    final hasGreen = boxes.any((box) {
      final d = box.decoration;
      if (d is! BoxDecoration) return false;
      final c = d.color;
      return c != null && c.g > 0.9 && c.r < 0.1 && c.a >= 0.92;
    });
    expect(hasGreen, isTrue);
  });
}
