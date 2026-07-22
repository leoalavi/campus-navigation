import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';
import 'package:mq_journey/features/scan/presentation/widgets/scene_rail.dart';

IndoorManifest _manifest(int n) => IndoorManifest(
  nodes: [
    for (var i = 0; i < n; i++)
      IndoorNode(id: 's$i', image: '$i.jpg', description: 'Scene $i'),
  ],
);

Widget _host({
  required IndoorManifest manifest,
  required String? selected,
  required ValueChanged<String> onSel,
  double textScale = 1.0,
  bool disableAnimations = false,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: Directionality(
      textDirection: dir,
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SceneRail(
            manifest: manifest,
            selectedSceneId: selected,
            onSceneSelected: onSel,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('renders a chip per scene', (tester) async {
    await tester.pumpWidget(
      _host(manifest: _manifest(3), selected: 's0', onSel: (_) {}),
    );
    expect(find.text('Scene 0'), findsOneWidget);
    expect(find.text('Scene 2'), findsOneWidget);
  });

  testWidgets('tapping a chip reports its scene id', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      _host(manifest: _manifest(3), selected: 's0', onSel: (id) => tapped = id),
    );
    await tester.tap(find.text('Scene 1'));
    expect(tapped, 's1');
  });

  testWidgets('falls back to id when description is empty', (tester) async {
    const m = IndoorManifest(
      nodes: const [IndoorNode(id: 'x9', image: 'a.jpg', description: '')],
    );
    await tester.pumpWidget(_host(manifest: m, selected: 'x9', onSel: (_) {}));
    expect(find.text('x9'), findsOneWidget);
  });

  testWidgets('empty manifest renders nothing', (tester) async {
    await tester.pumpWidget(
      _host(manifest: _manifest(0), selected: null, onSel: (_) {}),
    );
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('a distant, initially-offscreen selection is scrolled into view', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(manifest: _manifest(20), selected: 's19', onSel: (_) {}),
    );
    await tester.pumpAndSettle();
    // Index-based scroll reaches an item a lazy list never built via GlobalKey.
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('reduced motion jumps instead of animating', (tester) async {
    await tester.pumpWidget(
      _host(
        manifest: _manifest(20),
        selected: 's19',
        onSel: (_) {},
        disableAnimations: true,
      ),
    );
    await tester.pump(); // no long animation to settle
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('selected chip exposes one merged, selected semantics node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(manifest: _manifest(3), selected: 's2', onSel: (_) {}),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Scene 2')),
      containsSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('selected chip meets contrast + tap-target guidelines', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(manifest: _manifest(3), selected: 's0', onSel: (_) {}),
    );
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('survives 200% text scale without overflow', (tester) async {
    await tester.pumpWidget(
      _host(
        manifest: _manifest(3),
        selected: 's0',
        onSel: (_) {},
        textScale: 2.0,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsing hides the chips, leaving the round button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(manifest: _manifest(3), selected: 's0', onSel: (_) {}),
    );
    expect(find.text('Scene 0'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Scene 0'), findsNothing);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
  });

  testWidgets('re-expanding from the collapsed circle restores the chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(manifest: _manifest(3), selected: 's0', onSel: (_) {}),
    );
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Scene 0'), findsOneWidget);
  });
}
