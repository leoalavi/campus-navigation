import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_shell.dart';

const _sheetKey = Key('sheet-content');

Widget _app({
  Widget? footer,
  Object? resetKey,
  bool snappable = true,
  VoidCallback? onDismiss,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MapShell(
        mapView: const ColoredBox(color: Colors.black12),
        onCenterOnLocation: () {},
        onOpenSearch: () {},
        footer: footer,
        footerSnappable: snappable,
        footerResetKey: resetKey,
        onFooterDismiss: onDismiss,
      ),
    ),
  );
}

/// A child that fills whatever height the sheet allows (like a long list).
Widget _tallContent() => Container(key: _sheetKey, color: Colors.white);

/// A child with a short natural height (like a 2-row category list).
Widget _shortContent() => Container(
  key: _sheetKey,
  color: Colors.white,
  height: 180,
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

/// Tall deterministic viewport so `medium` (320) fits under the shell's
/// reserved top/bottom space regardless of the default 800×600 surface.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('snappable footer opens at medium and drags up to expand', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_app(footer: _tallContent()));
    await _settle(tester);

    final medium = tester.getSize(find.byKey(_sheetKey)).height;
    expect(medium, closeTo(320, 1));

    await tester.drag(find.byKey(_sheetKey), const Offset(0, -400));
    await _settle(tester);

    final expanded = tester.getSize(find.byKey(_sheetKey)).height;
    expect(expanded, greaterThan(medium + 50));
  });

  testWidgets('drag down collapses to peek; fling down at peek dismisses', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      _app(footer: _tallContent(), onDismiss: () => dismissed = true),
    );
    await _settle(tester);

    await tester.drag(find.byKey(_sheetKey), const Offset(0, 400));
    await _settle(tester);
    final peek = tester.getSize(find.byKey(_sheetKey)).height;
    expect(peek, closeTo(100, 1));
    expect(dismissed, isFalse);

    await tester.fling(find.byKey(_sheetKey), const Offset(0, 200), 1200);
    await _settle(tester);
    expect(dismissed, isTrue);
  });

  testWidgets('short content caps the sheet — no empty glass beyond content', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_app(footer: _shortContent()));
    await _settle(tester);

    // Natural height is 180 < medium, so the sheet hugs the content.
    expect(tester.getSize(find.byKey(_sheetKey)).height, closeTo(180, 2));

    // Dragging far upward must not open past the content's natural height.
    await tester.drag(find.byKey(_sheetKey), const Offset(0, -500));
    await _settle(tester);
    expect(tester.getSize(find.byKey(_sheetKey)).height, closeTo(180, 2));
  });

  testWidgets('map controls ride just above the sheet top edge', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_app(footer: _tallContent()));
    await _settle(tester);

    final locate = find.byIcon(Icons.my_location);
    final sheetTopBefore = tester.getTopLeft(find.byKey(_sheetKey)).dy;
    final buttonBottomBefore = tester.getBottomLeft(locate).dy;
    expect(buttonBottomBefore, lessThan(sheetTopBefore));

    await tester.drag(find.byKey(_sheetKey), const Offset(0, -400));
    await _settle(tester);

    final sheetTopAfter = tester.getTopLeft(find.byKey(_sheetKey)).dy;
    final buttonBottomAfter = tester.getBottomLeft(locate).dy;
    // Sheet moved up; the control moved up with it and stays above it.
    expect(sheetTopAfter, lessThan(sheetTopBefore - 50));
    expect(buttonBottomAfter, lessThan(buttonBottomBefore - 50));
    expect(buttonBottomAfter, lessThan(sheetTopAfter));
  });

  testWidgets('controls sit at the default bottom position with no footer', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_app(footer: null));
    await _settle(tester);

    final screen = tester.getSize(find.byType(MapShell));
    final locateBottom = tester
        .getBottomLeft(find.byIcon(Icons.my_location))
        .dy;
    // Near the bottom of the shell (default base offset), not floated high.
    expect(screen.height - locateBottom, lessThan(80));
  });

  testWidgets('switching to different content reopens to medium', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_app(footer: _tallContent(), resetKey: 'a'));
    await _settle(tester);

    // Collapse to peek first.
    await tester.drag(find.byKey(_sheetKey), const Offset(0, 400));
    await _settle(tester);
    expect(tester.getSize(find.byKey(_sheetKey)).height, closeTo(100, 1));

    // New category (resetKey change) → sheet reopens to medium.
    await tester.pumpWidget(_app(footer: _tallContent(), resetKey: 'b'));
    await _settle(tester);
    expect(tester.getSize(find.byKey(_sheetKey)).height, closeTo(320, 1));
  });
}
