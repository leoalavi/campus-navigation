import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/router/liquid_tab_bar.dart';

void main() {
  Finder viewfinder() => find.byWidgetPredicate(
    (w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == '_ViewfinderPainter',
  );

  Widget host() {
    var index = 0;
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: StatefulBuilder(
          builder: (context, setState) => LiquidTabBar(
            currentIndex: index,
            onSelected: (i) => setState(() => index = i),
            color: Colors.black,
            accent: Colors.red,
            items: const [
              LiquidNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                fx: TabFx.homecoming,
              ),
              LiquidNavItem(
                icon: Icons.qr_code_scanner_outlined,
                activeIcon: Icons.qr_code_scanner,
                label: 'Scan',
                fx: TabFx.scanline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Four-tab host mirroring the real shell, in a caller-chosen direction, so
  /// tap→index mapping can be asserted independently of locale.
  Widget directionalHost({
    required TextDirection direction,
    required void Function(int) onSelected,
    int currentIndex = 0,
  }) {
    return MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          bottomNavigationBar: LiquidTabBar(
            currentIndex: currentIndex,
            onSelected: onSelected,
            color: Colors.black,
            accent: Colors.red,
            items: const [
              LiquidNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                fx: TabFx.homecoming,
              ),
              LiquidNavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: 'Journey',
                fx: TabFx.rotateOpen,
              ),
              LiquidNavItem(
                icon: Icons.qr_code_scanner_outlined,
                activeIcon: Icons.qr_code_scanner,
                label: 'Scan',
                fx: TabFx.scanline,
              ),
              LiquidNavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                fx: TabFx.spin,
              ),
            ],
          ),
        ),
      ),
    );
  }

  group('tap lands on the tab the user actually touched', () {
    for (final (direction, name) in const [
      (TextDirection.ltr, 'ltr'),
      (TextDirection.rtl, 'rtl'),
    ]) {
      testWidgets('$name: each icon reports its own index', (tester) async {
        final selected = <int>[];
        await tester.pumpWidget(
          directionalHost(
            direction: direction,
            onSelected: selected.add,
          ),
        );

        // The icon a user sees for tab i must report i, whichever edge the
        // layout places it against. Under RTL the Row mirrors children, so a
        // hit test that measures dx from the left edge reports (n-1-i) — the
        // reported "tapping Home opens Settings" bug.
        // Tab 0 is the selected one, so it renders its *active* icon; the
        // rest render their outlined variant.
        const expected = <(IconData, int)>[
          (Icons.home, 0),
          (Icons.map_outlined, 1),
          (Icons.qr_code_scanner_outlined, 2),
          (Icons.settings_outlined, 3),
        ];

        for (final (icon, index) in expected) {
          selected.clear();
          await tester.tap(find.byIcon(icon), warnIfMissed: false);
          await tester.pump();
          expect(
            selected,
            [index],
            reason:
                'tapping the $icon icon in $name should select index $index',
          );
          await tester.pumpAndSettle();
        }
      });
    }
  });

  testWidgets('rtl: the selection lens sits over the selected tab', (
    tester,
  ) async {
    // The lens is positioned from the *start* edge, so in RTL it must land on
    // the right-hand side for tab 0 — a hard-coded `left:` would put it over
    // Settings instead.
    await tester.pumpWidget(
      directionalHost(
        direction: TextDirection.rtl,
        onSelected: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    final barCentre = tester.getCenter(find.byType(LiquidTabBar)).dx;
    final homeCentre = tester.getCenter(find.byIcon(Icons.home)).dx;
    final lens = tester.getCenter(
      find
          .descendant(
            of: find.byType(LiquidTabBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );

    expect(homeCentre, greaterThan(barCentre)); // sanity: RTL put Home right
    expect(
      (lens.dx - homeCentre).abs(),
      lessThan(24),
      reason: 'lens should be centred on the selected (Home) tab',
    );
  });

  testWidgets('scanline fx plays on select and leaves no overlays behind', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    // Idle: no viewfinder brackets painted.
    expect(viewfinder(), findsNothing);

    await tester.tap(
      find.byIcon(Icons.qr_code_scanner_outlined),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // mid-scan
    expect(viewfinder(), findsOneWidget);

    await tester.pumpAndSettle();
    expect(viewfinder(), findsNothing); // sequence ends clean
  });

  testWidgets(
    'homecoming fx plays on re-select and leaves no overlays behind',
    (tester) async {
      Finder sunrise() => find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_SunrisePainter',
      );

      await tester.pumpWidget(host());
      expect(sunrise(), findsNothing); // initially selected but idle

      // Leave home, then come back — the flourish plays on becoming selected.
      await tester.tap(
        find.byIcon(Icons.qr_code_scanner_outlined),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.home_outlined), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550)); // ray-burst stage
      expect(sunrise(), findsOneWidget);

      await tester.pumpAndSettle();
      expect(sunrise(), findsNothing);
    },
  );
}
