import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_navigation/app/l10n/generated/app_localizations.dart';
import 'package:campus_navigation/features/map/domain/entities/map_renderer_type.dart';
import 'package:campus_navigation/features/map/presentation/widgets/map_bottom_sheet.dart';
import 'package:campus_navigation/features/map/presentation/widgets/map_shell.dart';

/// Regression: with a category sheet (e.g. Student Services) docked, the
/// Locate-me button rode above the sheet but the Layers button stayed pinned
/// to the bottom and was buried under the list. Both must share one anchor
/// just above the sheet's top edge.
void main() {
  final layers = find.byKey(const ValueKey('map-layers-button'));
  final locate = find.byKey(const ValueKey('map-locate-button'));
  final handle = find.byKey(const ValueKey('map-sheet-drag-handle'));

  Future<void> pumpShell(
    WidgetTester tester, {
    required Size size,
    required bool withSheet,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MapShell(
              mapView: const ColoredBox(color: Colors.green),
              renderer: MapRendererType.campus,
              onRendererChanged: (_) {},
              onCenterOnLocation: () {},
              onOpenSearch: () {},
              onOpenOverlayPicker: () {},
              footer: withSheet
                  ? ListView(
                      children: [
                        for (var i = 0; i < 30; i++)
                          ListTile(title: Text('Service $i')),
                      ],
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double sheetTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(MapBottomSheet)).dy;

  for (final (label, size) in const [
    ('small phone', Size(320, 568)),
    ('standard phone', Size(390, 844)),
    ('tablet', Size(820, 1180)),
  ]) {
    testWidgets('$label: controls share a baseline with no sheet', (
      tester,
    ) async {
      await pumpShell(tester, size: size, withSheet: false);
      expect(tester.getBottomLeft(layers).dy, tester.getBottomLeft(locate).dy);
      expect(tester.getBottomLeft(layers).dy, lessThan(size.height));
    });

    testWidgets('$label: both controls sit above a compact sheet', (
      tester,
    ) async {
      await pumpShell(tester, size: size, withSheet: true);
      final top = sheetTop(tester);
      final layersBottom = tester.getBottomLeft(layers).dy;
      final locateBottom = tester.getBottomLeft(locate).dy;
      expect(layersBottom, locateBottom, reason: 'one shared anchor');
      expect(layersBottom, lessThanOrEqualTo(top), reason: 'above the sheet');
      // Start/end of the same row.
      expect(
        tester.getCenter(layers).dx,
        lessThan(tester.getCenter(locate).dx),
      );
    });
  }

  testWidgets('controls follow the sheet as it is dragged and step aside '
      'when it is fully expanded', (tester) async {
    await pumpShell(tester, size: const Size(390, 844), withSheet: true);
    final compactLayers = tester.getBottomLeft(layers).dy;

    // Drag partway up: still visible, still above the (taller) sheet.
    await tester.drag(handle, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Fling to expanded: no room above the sheet, so the controls fade out
    // and stop taking taps instead of overlapping the search overlay.
    await tester.fling(handle, const Offset(0, -400), 2000);
    await tester.pumpAndSettle();
    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(of: layers, matching: find.byType(AnimatedOpacity)).first,
    );
    expect(opacity.opacity, 0);

    // Back to compact: controls return above the sheet.
    await tester.fling(handle, const Offset(0, 400), 2000);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(layers).dy,
      lessThanOrEqualTo(sheetTop(tester)),
    );
    expect(tester.getBottomLeft(layers).dy, isNot(compactLayers + 1000));
  });
}
