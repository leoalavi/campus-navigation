import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/data/datasources/building_registry_source.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/open_day/presentation/widgets/event_actions_sheet.dart';

const _building = Building(id: 'wallys-1', code: 'wallys-1', name: "1 Wally's Walk");

final _mappableEvent = OpenDayEvent(
  id: 'evt-1',
  title: 'COMP1010 Info Session',
  startTime: DateTime(2026, 8, 22, 10),
  endTime: DateTime(2026, 8, 22, 11),
  venueName: "1 Wally's Walk",
  bachelorIds: const ['comp-sci'],
  buildingCode: 'wallys-1',
);

final _unmappableEvent = OpenDayEvent(
  id: 'evt-2',
  title: 'Careers Fair',
  startTime: DateTime(2026, 8, 22, 12),
  endTime: DateTime(2026, 8, 22, 13),
  venueName: 'Off-campus pop-up',
  bachelorIds: const [],
);

Widget _app({required OpenDayEvent event, required List<Building> buildings}) {
  final router = GoRouter(
    initialLocation: '/open-day',
    routes: [
      GoRoute(
        path: '/open-day',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => EventActionsSheet.show(context, event),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/map',
        name: 'map',
        builder: (_, _) => const Scaffold(body: Text('map-page')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      buildingRegistryProvider.overrideWith((ref) async => buildings),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('shows the campus-map action for an event with a resolvable venue', (
    tester,
  ) async {
    await tester.pumpWidget(_app(event: _mappableEvent, buildings: const [_building]));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(EventActionsSheet)),
    )!;
    expect(find.text(l10n.openDay_viewInCampusMap), findsOneWidget);
  });

  testWidgets('shows the no-mappable-venue copy when the venue cannot be resolved', (
    tester,
  ) async {
    await tester.pumpWidget(_app(event: _unmappableEvent, buildings: const [_building]));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(EventActionsSheet)),
    )!;
    expect(find.text(l10n.openDay_noMappableVenue), findsOneWidget);
  });

  testWidgets('tapping the campus-map action closes the sheet and navigates to Map', (
    tester,
  ) async {
    await tester.pumpWidget(_app(event: _mappableEvent, buildings: const [_building]));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(EventActionsSheet)),
    )!;
    await tester.tap(find.text(l10n.openDay_viewInCampusMap));
    await tester.pumpAndSettle();

    expect(find.text('map-page'), findsOneWidget);
  });
}
