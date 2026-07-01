import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/presentation/widgets/building_actions_sheet.dart';

void main() {
  testWidgets('shows the building name and a Navigate action', (tester) async {
    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          name: 'map',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BuildingActionsSheet.show(
                  context,
                  buildingId: 'C3A',
                  buildingName: 'Central Courtyard',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Central Courtyard'), findsOneWidget);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(BuildingActionsSheet)),
    )!;
    expect(find.text(l10n.navigateOnCampus), findsOneWidget);
  });

  testWidgets('tapping Navigate dismisses the sheet', (tester) async {
    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          name: 'map',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BuildingActionsSheet.show(
                  context,
                  buildingId: 'C3A',
                  buildingName: 'Central Courtyard',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(BuildingActionsSheet)),
    )!;
    await tester.tap(find.text(l10n.navigateOnCampus));
    await tester.pumpAndSettle();

    expect(find.byType(BuildingActionsSheet), findsNothing);
  });
}
