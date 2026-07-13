import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_mode_toggle.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_shell.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets('renders the mode toggle in Campus Map mode', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MapShell(
          mapView: const SizedBox.shrink(),
          onCenterOnLocation: () {},
          onOpenSearch: () {},
          mapMode: MapMode.campusMap,
          onMapModeChanged: (_) {},
        ),
      ),
    );

    expect(find.byType(MapModeToggle), findsOneWidget);
  });

  testWidgets('keeps the mode toggle reachable in AR mode', (tester) async {
    MapMode? changed;
    await tester.pumpWidget(
      _wrap(
        MapShell(
          mapView: const SizedBox.shrink(),
          onCenterOnLocation: () {},
          onOpenSearch: () {},
          mapMode: MapMode.ar,
          onMapModeChanged: (m) => changed = m,
          arContent: const Text('ar-content'),
        ),
      ),
    );

    // AR content is shown...
    expect(find.text('ar-content'), findsOneWidget);
    // ...and the toggle is still present so the user can return to Campus Map.
    expect(find.byType(MapModeToggle), findsOneWidget);

    await tester.tap(find.text('Campus Map'));
    expect(changed, MapMode.campusMap);
  });

  testWidgets(
    'hides the AR-mode toggle when showArModeToggle is false (indoor preview)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          MapShell(
            mapView: const SizedBox.shrink(),
            onCenterOnLocation: () {},
            onOpenSearch: () {},
            mapMode: MapMode.ar,
            onMapModeChanged: (_) {},
            showArModeToggle: false,
            arContent: const Text('indoor-preview'),
          ),
        ),
      );

      // The preview owns the top bar, so the floating toggle must not overlap it.
      expect(find.text('indoor-preview'), findsOneWidget);
      expect(find.byType(MapModeToggle), findsNothing);
    },
  );
}
