import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/map/presentation/pages/map_page.dart';
import 'package:mq_journey/features/map/presentation/widgets/building_search_sheet.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_shell.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

/// Opening the building search must be one clean transition.
///
/// The reported flicker was not a duplicated route: exactly one sheet opened.
/// It was that the search surface was a *transparent* modal, so the map kept
/// painting underneath it — including eight `BackdropFilter` glass layers,
/// each re-sampling a full-screen blur every frame behind a surface that
/// already covered them. On web every blur is a save-layer readback, which is
/// what pulsed. The search is now an opaque route, so the framework stops
/// painting the map once it is open.

class _FakeSettings extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

class _FakeRepo implements MapRepository {
  _FakeRepo(this.buildings);
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

final _a = Building.fromJson({
  'id': 'BLD-A',
  'code': 'BLDA',
  'name': 'Building A',
  'location': {'lat': -33.775, 'lng': 151.113},
  'category': 'academic',
});
final _b = Building.fromJson({
  'id': 'BLD-B',
  'code': 'BLDB',
  'name': 'Building B',
  'location': {'lat': -33.776, 'lng': 151.114},
  'category': 'academic',
});

Widget _app() {
  final router = GoRouter(
    initialLocation: '/map',
    routes: [
      GoRoute(
        path: '/map',
        name: RouteNames.map,
        builder: (_, _) => const MapPage(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      mapRepositoryProvider.overrideWithValue(_FakeRepo([_a, _b])),
      settingsControllerProvider.overrideWith(_FakeSettings.new),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _boot(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The map's search *button*, scoped to the shell so it never collides with
/// the search field's identically-worded hint once the surface is open.
Finder get _pill => find.descendant(
  of: find.byType(MapShell),
  matching: find.text('Search buildings...'),
);
Finder get _sheet => find.byType(BuildingSearchSheet);

void main() {
  testWidgets('one tap opens exactly one search surface', (tester) async {
    await _boot(tester);
    await tester.tap(_pill);
    await tester.pumpAndSettle();

    expect(_sheet, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated rapid taps do not open duplicates', (tester) async {
    await _boot(tester);
    // Three taps inside the transition window — the guard plus the route
    // push must still yield a single surface.
    await tester.tap(_pill, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tap(_pill, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tap(_pill, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(_sheet, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the map stops blurring underneath once search is open', (
    tester,
  ) async {
    await _boot(tester);
    final before = find.byType(BackdropFilter).evaluate().length;
    expect(
      before,
      greaterThan(0),
      reason: 'sanity: the map really does carry glass layers',
    );

    await tester.tap(_pill);
    await tester.pumpAndSettle();

    expect(
      find.byType(BackdropFilter),
      findsNothing,
      reason:
          'an opaque search route must stop the map (and its $before blur '
          'layers) from painting — that cost is what made opening flicker',
    );
  });

  testWidgets('open, close and reopen stays stable', (tester) async {
    await _boot(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(_pill);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget, reason: 'cycle $i should open');

      // Back closes it cleanly and returns to the map.
      Navigator.of(tester.element(_sheet)).pop();
      // Fixed pumps, not pumpAndSettle: the map screen animates continuously
      // (glass + live location affordances), so it never reaches a quiescent
      // frame once it is back on top.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_sheet, findsNothing, reason: 'cycle $i should close');
      expect(_pill, findsOneWidget, reason: 'cycle $i should restore the map');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('autofocus raises no exception and the list is not blank', (
    tester,
  ) async {
    await _boot(tester);
    await tester.tap(_pill);
    await tester.pumpAndSettle();

    // The field took focus without throwing...
    expect(tester.takeException(), isNull);
    // ...and the results are present immediately, with no transient empty
    // state standing in for a still-loading registry.
    expect(find.text('Building A'), findsOneWidget);
    expect(find.text('Building B'), findsOneWidget);
  });

  testWidgets('picking a result goes straight to the map with its detail', (
    tester,
  ) async {
    // No intermediate "Show in Campus Map" sheet: with one campus map there
    // is nothing to choose, so the extra tap was pure friction.
    await _boot(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapPage)),
    );

    await tester.tap(_pill);
    await tester.pumpAndSettle();
    expect(_sheet, findsOneWidget);

    await tester.tap(find.text('Building A').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Search surface closed, and we are back on the map...
    expect(_sheet, findsNothing);
    expect(find.byType(MapShell), findsOneWidget);
    // ...with the building selected (marker) and its panel open.
    expect(
      container.read(mapControllerProvider).value!.selectedBuilding?.code,
      'BLDA',
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(MapPage)))!;
    expect(
      find.byTooltip(l10n.close),
      findsOneWidget,
      reason: 'the location detail panel should be showing',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no intermediate action sheet is shown for a result', (
    tester,
  ) async {
    await _boot(tester);
    await tester.tap(_pill);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Building A').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final l10n = AppLocalizations.of(tester.element(find.byType(MapPage)))!;
    expect(
      find.text(l10n.navigateOnCampus),
      findsNothing,
      reason: 'the single-action handoff sheet should be gone',
    );
  });
}
