import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/nav_instruction.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/presentation/widgets/route_panel.dart';

const _building = Building(
  id: 'wallys-1',
  code: 'wallys-1',
  name: "1 Wally's Walk",
);

MapRoute _route() {
  return MapRoute(
    travelMode: TravelMode.walk,
    distanceMeters: 350,
    durationSeconds: 300,
    encodedPolyline: '',
    instructions: const [
      NavInstruction(text: 'Head north on Wally\'s Walk', distanceMeters: 100),
      NavInstruction(text: 'Turn right', distanceMeters: 250),
    ],
  );
}

Widget _app({
  Building? selectedBuilding = _building,
  MapRoute? route,
  bool isLoading = false,
  bool isNavigating = false,
  bool hasArrived = false,
  VoidCallback? onClearRoute,
  VoidCallback? onClearSelection,
  VoidCallback? onStartNavigation,
  VoidCallback? onStopNavigation,
  VoidCallback? onDismissArrival,
  Future<void> Function()? onLoadRoute,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: RoutePanel(
        selectedBuilding: selectedBuilding,
        route: route,
        currentLocation: null,
        travelMode: TravelMode.walk,
        supportedTravelModes: const [TravelMode.walk, TravelMode.drive],
        isLoading: isLoading,
        isNavigating: isNavigating,
        hasArrived: hasArrived,
        onLoadRoute: onLoadRoute ?? () async {},
        onClearRoute: onClearRoute ?? () {},
        onClearSelection: onClearSelection ?? () {},
        onTravelModeChanged: (_) {},
        onStartNavigation: onStartNavigation ?? () {},
        onStopNavigation: onStopNavigation ?? () {},
        onDismissArrival: onDismissArrival ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing when no building is selected', (tester) async {
    await tester.pumpWidget(_app(selectedBuilding: null));

    expect(find.byType(RoutePanel), findsOneWidget);
    expect(find.text("1 Wally's Walk"), findsNothing);
  });

  testWidgets('shows the arrival card when hasArrived is true', (tester) async {
    await tester.pumpWidget(_app(hasArrived: true));

    final l10n = AppLocalizations.of(tester.element(find.byType(RoutePanel)))!;
    expect(find.text(l10n.youveArrived), findsOneWidget);
    expect(find.text("1 Wally's Walk"), findsOneWidget);
  });

  testWidgets(
    'shows Get Directions when no route is loaded yet, and invokes onLoadRoute',
    (tester) async {
      var loaded = false;
      await tester.pumpWidget(_app(onLoadRoute: () async => loaded = true));

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RoutePanel)),
      )!;
      await tester.tap(find.text(l10n.walkingDirections));
      await tester.pump();

      expect(loaded, isTrue);
    },
  );

  testWidgets('shows route info and travel mode pills once a route is loaded', (
    tester,
  ) async {
    await tester.pumpWidget(_app(route: _route()));

    final l10n = AppLocalizations.of(tester.element(find.byType(RoutePanel)))!;
    expect(find.text(l10n.walk), findsOneWidget);
    expect(find.text(l10n.drive), findsOneWidget);
    expect(find.text(l10n.clear), findsOneWidget);
  });

  testWidgets('tapping Clear invokes onClearRoute', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      _app(route: _route(), onClearRoute: () => cleared = true),
    );

    final l10n = AppLocalizations.of(tester.element(find.byType(RoutePanel)))!;
    await tester.tap(find.text(l10n.clear));
    await tester.pump();

    expect(cleared, isTrue);
  });

  testWidgets(
    'while navigating, shows Stop navigation and hides travel mode pills',
    (tester) async {
      await tester.pumpWidget(_app(route: _route(), isNavigating: true));

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RoutePanel)),
      )!;
      expect(find.text(l10n.stopNavigation), findsOneWidget);
      expect(find.text(l10n.drive), findsNothing);
    },
  );

  testWidgets('tapping Stop navigation invokes onStopNavigation', (
    tester,
  ) async {
    var stopped = false;
    await tester.pumpWidget(
      _app(
        route: _route(),
        isNavigating: true,
        onStopNavigation: () => stopped = true,
      ),
    );

    final l10n = AppLocalizations.of(tester.element(find.byType(RoutePanel)))!;
    await tester.tap(find.text(l10n.stopNavigation));
    await tester.pump();

    expect(stopped, isTrue);
  });

  testWidgets('minimising during navigation collapses to the peek bar', (
    tester,
  ) async {
    await tester.pumpWidget(_app(route: _route(), isNavigating: true));

    final l10n = AppLocalizations.of(tester.element(find.byType(RoutePanel)))!;
    await tester.tap(find.byTooltip(l10n.routePanelMinimize));
    await tester.pumpAndSettle();

    expect(find.text(l10n.stopNavigation), findsNothing);
    expect(find.text('Head north on Wally\'s Walk'), findsOneWidget);
  });
}
