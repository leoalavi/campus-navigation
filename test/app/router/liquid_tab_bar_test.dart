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
                fx: TabFx.bounce,
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
}
