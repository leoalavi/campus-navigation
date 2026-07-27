import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/data/datasources/building_registry_source.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/open_day/presentation/actions/open_event_venue.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

/// Behaviour of the venue button when the building registry misbehaves.
///
/// The button must never sit silent: it either navigates (directly, or via
/// the event's own building code) or it explains itself and offers a retry.

class _FakeSettingsController extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

/// Supplies the *map's* copy of the building list, independent of the
/// registry provider — that separation is what makes a fallback possible.
class _FakeMapRepository implements MapRepository {
  _FakeMapRepository(this.buildings);
  final List<Building> buildings;

  @override
  Future<List<Building>> getBuildings({bool forceRefresh = false}) async =>
      buildings;

  @override
  Future<LocationPermissionState> ensureLocationPermission() async =>
      LocationPermissionState.granted;

  @override
  Future<LocationSample?> getCurrentLocation() async => null;

  @override
  Stream<LocationSample> watchLocation() => const Stream.empty();

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<MapRoute> getRoute({
    required LocationSample origin,
    required Building destination,
    required TravelMode travelMode,
  }) async => MapRoute(
    travelMode: travelMode,
    distanceMeters: 0,
    durationSeconds: 0,
    encodedPolyline: '',
    instructions: const [],
  );
}

const _venue = Building(id: 'wallys-29', code: '29WW', name: "29 Wally's Walk");

final _event = OpenDayEvent(
  id: 'evt-1',
  title: 'Bachelor of Arts',
  startTime: DateTime(2026, 8, 15, 14),
  endTime: DateTime(2026, 8, 15, 14, 45),
  venueName: "Theatre 1, 29 Wally's Walk",
  bachelorIds: const ['arts'],
  buildingCode: '29WW',
);

late ProviderContainer _container;

Widget _app({
  required Future<List<Building>> Function() registry,
  List<Building> mapBuildings = const [_venue],
  OpenDayEvent? event,
}) {
  final router = GoRouter(
    initialLocation: '/open-day',
    routes: [
      GoRoute(
        path: '/open-day',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openEventVenueOnMap(context, event ?? _event),
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
      buildingRegistryProvider.overrideWith((ref) => registry()),
      mapRepositoryProvider.overrideWithValue(_FakeMapRepository(mapBuildings)),
      settingsControllerProvider.overrideWith(_FakeSettingsController.new),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// Brings the map controller to a data state so the fallback check can see
/// its buildings, mirroring a user who has already had the map tab warm.
Future<void> _warmMap(WidgetTester tester) async {
  _container = ProviderScope.containerOf(
    tester.element(find.text('open')),
    listen: false,
  );
  _container.read(mapControllerProvider);
  await tester.pumpAndSettle();
}

/// Waits out the venue lookup.
///
/// A registry that fails does not surface as `AsyncError` in the vendored
/// Riverpod — it stays `AsyncLoading` forever — so every failure path only
/// resolves once [kVenueLookupTimeout] fires. `pumpAndSettle` alone would
/// return long before that and see nothing.
Future<void> _settleLookup(WidgetTester tester) async {
  await tester.pump(kVenueLookupTimeout + const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

String _l10n(WidgetTester tester, String Function(AppLocalizations) pick) =>
    pick(AppLocalizations.of(tester.element(find.byType(Scaffold).first))!);

void main() {
  testWidgets('1. registry loads successfully — navigates to the venue', (
    tester,
  ) async {
    await tester.pumpWidget(_app(registry: () async => const [_venue]));
    await _warmMap(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('map-page'), findsOneWidget);
    expect(
      find.text(_l10n(tester, (l) => l.openDay_venueLookupFailed)),
      findsNothing,
    );
  });

  testWidgets('2. registry throws — still navigates using the event code', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(registry: () async => throw Exception('registry offline')),
    );
    await _warmMap(tester);

    await tester.tap(find.text('open'));
    await _settleLookup(tester);

    // The event carries 29WW and the map knows that building, so the user
    // still gets where they were going.
    expect(find.text('map-page'), findsOneWidget);
  });

  testWidgets('3. registry times out — bounded, then falls back', (
    tester,
  ) async {
    // A future that never completes: before the timeout this hung forever and
    // the button did nothing at all.
    final stuck = Completer<List<Building>>();
    await tester.pumpWidget(_app(registry: () => stuck.future));
    await _warmMap(tester);

    await tester.tap(find.text('open'));
    await tester.pump();

    // Still waiting, nothing decided yet.
    expect(find.text('map-page'), findsNothing);

    await _settleLookup(tester);

    expect(find.text('map-page'), findsOneWidget);
  });

  testWidgets('4. fallback data available — lands on the event own building', (
    tester,
  ) async {
    // Registry down, but the map holds the building the event names. The
    // fallback must use *that* building, never a default or nearby one.
    await tester.pumpWidget(
      _app(
        registry: () async => throw Exception('down'),
        mapBuildings: const [
          Building(id: 'other-1', code: 'OTHER', name: 'Somewhere else'),
          _venue,
        ],
      ),
    );
    await _warmMap(tester);

    await tester.tap(find.text('open'));
    await _settleLookup(tester);

    expect(find.text('map-page'), findsOneWidget);
    final selected = _container
        .read(mapControllerProvider)
        .value!
        .selectedBuilding;
    expect(selected?.code, '29WW');
  });

  testWidgets('5. no fallback data — shows a localised error with Retry', (
    tester,
  ) async {
    // Registry down AND the map cannot place the code: the one case where we
    // genuinely cannot navigate. It must say so and offer a way forward.
    await tester.pumpWidget(
      _app(
        registry: () async => throw Exception('down'),
        mapBuildings: const [],
      ),
    );
    await _warmMap(tester);

    await tester.tap(find.text('open'));
    await _settleLookup(tester);

    expect(find.text('map-page'), findsNothing);
    expect(
      find.text(_l10n(tester, (l) => l.openDay_venueLookupFailed)),
      findsOneWidget,
    );
    expect(find.text(_l10n(tester, (l) => l.retry)), findsOneWidget);
  });

  testWidgets('an event with no building code says so and offers no retry', (
    tester,
  ) async {
    // Permanent property of the event — a retry could never change it.
    final unmappable = OpenDayEvent(
      id: 'evt-2',
      title: 'Careers Fair',
      startTime: DateTime(2026, 8, 15, 12),
      endTime: DateTime(2026, 8, 15, 12, 45),
      venueName: 'Off-campus pop-up',
      bachelorIds: const [],
    );
    await tester.pumpWidget(
      _app(registry: () async => const [_venue], event: unmappable),
    );
    await _warmMap(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text(_l10n(tester, (l) => l.openDay_noMappableVenue)),
      findsOneWidget,
    );
    expect(find.text(_l10n(tester, (l) => l.retry)), findsNothing);
    expect(find.text('map-page'), findsNothing);
  });

  testWidgets('Retry re-reads the registry and then navigates', (tester) async {
    // Gated by an explicit flag rather than an attempt counter: the provider
    // may rebuild itself more than once, so "fail only the first read" is not
    // a stable way to hold it in the failed state.
    var registryDown = true;
    var reads = 0;
    await tester.pumpWidget(
      _app(
        registry: () async {
          reads++;
          if (registryDown) throw Exception('transient');
          return const [_venue];
        },
        mapBuildings: const [],
      ),
    );
    await _warmMap(tester);

    await tester.tap(find.text('open'));
    await _settleLookup(tester);
    expect(find.text(_l10n(tester, (l) => l.retry)), findsOneWidget);
    expect(find.text('map-page'), findsNothing);

    final readsBeforeRetry = reads;
    registryDown = false;
    await tester.tap(find.text(_l10n(tester, (l) => l.retry)));
    await tester.pumpAndSettle();

    expect(
      reads,
      greaterThan(readsBeforeRetry),
      reason: 'retry must re-read the registry, not reuse the failed result',
    );
    expect(find.text('map-page'), findsOneWidget);
  });
}
