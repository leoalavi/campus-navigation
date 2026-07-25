import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/data/datasources/building_registry_source.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/open_day/presentation/actions/open_event_venue.dart';

const _building = Building(
  id: 'wallys-1',
  code: 'wallys-1',
  name: "1 Wally's Walk",
);

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

Widget _app({
  required OpenDayEvent event,
  List<Building> buildings = const [],
  // A loader rather than a bare Future: an eagerly-constructed `Future.error`
  // is an unhandled zone error the moment it is created, which fails the test
  // before the provider ever reads it.
  Future<List<Building>> Function()? loader,
}) {
  final router = GoRouter(
    initialLocation: '/open-day',
    routes: [
      GoRoute(
        path: '/open-day',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openEventVenueOnMap(context, event),
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
      buildingRegistryProvider.overrideWith(
        (ref) => loader?.call() ?? Future.value(buildings),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('a mappable venue goes straight to the Map — no extra tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(event: _mappableEvent, buildings: const [_building]),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Previously this landed on a "View in Campus Map" sheet that needed a
    // second tap. With one campus map there is nothing to choose.
    expect(find.text('map-page'), findsOneWidget);
    expect(find.text('View in Campus Map'), findsNothing);
  });

  testWidgets('waits for venue resolution, then navigates once resolved', (
    tester,
  ) async {
    final buildings = Completer<List<Building>>();
    await tester.pumpWidget(
      _app(event: _mappableEvent, loader: () => buildings.future),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    // Nothing decided yet: neither a premature navigation nor an error.
    expect(find.text('map-page'), findsNothing);
    expect(find.text(_noVenueCopy(tester)), findsNothing);

    buildings.complete(const [_building]);
    await tester.pumpAndSettle();

    expect(find.text('map-page'), findsOneWidget);
  });

  testWidgets('an unmappable venue explains itself and does not navigate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(event: _unmappableEvent, buildings: const [_building]),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(_noVenueCopy(tester)), findsOneWidget);
    expect(find.text('map-page'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an event whose building cannot be found in the registry does not navigate',
    (tester) async {
      // buildingCode is set, but no matching building exists — must not
      // navigate to a map that cannot place the venue.
      await tester.pumpWidget(
        _app(event: _mappableEvent, buildings: const []),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('map-page'), findsNothing);
      expect(find.text(_noVenueCopy(tester)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opening the same venue twice still navigates', (tester) async {
    await tester.pumpWidget(
      _app(event: _mappableEvent, buildings: const [_building]),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('map-page'), findsOneWidget);

    // Back to the list, then open it again — the campus-map intent bump must
    // re-emit the selection despite go_router's same-URL no-op.
    router(tester).go('/open-day');
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('map-page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GoRouter router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

/// The localised "this venue has no map location" copy, read from the running
/// app rather than duplicated as a literal — a stale literal would make these
/// assertions pass for the wrong reason.
String _noVenueCopy(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!
        .openDay_noMappableVenue;
