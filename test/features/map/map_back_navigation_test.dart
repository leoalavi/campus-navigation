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
import 'package:mq_journey/features/map/presentation/actions/open_building_on_map.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/map/presentation/pages/map_page.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

/// Back navigation out of the Campus Map.
///
/// The scanned-QR venue card lives at a TOP-LEVEL route (`/location/:id`)
/// while `/map` lives inside the StatefulShellRoute. Opening the map with
/// `go` therefore tore the card off the stack, leaving the map with nothing
/// to return to — the bottom nav was the only way out. These tests pin the
/// push policy, the resulting back affordance, and the fact that the venue
/// page survives underneath with its state intact.

class _FakeSettingsController extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

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

final _wallys = Building.fromJson({
  'id': 'wallys-11',
  'code': '11WW',
  'name': "11 Wally's Walk",
  'location': {'lat': -33.775, 'lng': 151.113},
  'category': 'academic',
});

/// Stand-in for the scanned-venue card. The "Added to Your Day" toggle is
/// local widget state on purpose: if the route were replaced (or rebuilt) the
/// flag would reset, so asserting it survives proves the page was kept alive
/// beneath the pushed map rather than torn down and recreated.
class _VenuePage extends StatefulWidget {
  const _VenuePage({required this.venueId});
  final String venueId;

  @override
  State<_VenuePage> createState() => _VenuePageState();
}

class _VenuePageState extends State<_VenuePage> {
  bool _addedToMyDay = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('venue-${widget.venueId}'),
          Text(_addedToMyDay ? 'added' : 'not-added'),
          ElevatedButton(
            onPressed: () => setState(() => _addedToMyDay = true),
            child: const Text('add-to-my-day'),
          ),
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openBuildingOnCampusMap(
                context,
                '11WW',
                policy: MapOpenPolicy.push,
              ),
              child: const Text('view-on-campus-map'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors the real topology: a top-level venue route plus `/map` nested in a
/// stateful shell, so push/pop behaves exactly as it does in the app.
GoRouter _router({String initialLocation = '/location/abc'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/location/:locationId',
        builder: (context, state) =>
            _VenuePage(venueId: state.pathParameters['locationId']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: RouteNames.home,
                builder: (_, _) => const Scaffold(body: Text('home-branch')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                name: RouteNames.map,
                builder: (context, state) => MapPage(
                  initialBuildingId: state.uri.queryParameters['building'],
                  showBackButton: state.uri.queryParameters['back'] == '1',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Widget _app(GoRouter router) {
  return ProviderScope(
    overrides: [
      mapRepositoryProvider.overrideWithValue(_FakeMapRepository([_wallys])),
      settingsControllerProvider.overrideWith(_FakeSettingsController.new),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// MapPage animates continuously, so `pumpAndSettle` never returns. Pump a
/// generous fixed budget instead — long enough that a route transition is
/// fully finished and the outgoing page is gone from the tree (mid-transition
/// both pages are mounted, which otherwise looks like a duplicate route).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _openMap(WidgetTester tester) async {
  await tester.tap(find.text('view-on-campus-map'));
  await _settle(tester);
  await _settle(tester);
}

void main() {
  Future<void> pumpApp(WidgetTester tester, GoRouter router) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Wide surface so the map's top overlay row lays out without overflow.
    await tester.pumpWidget(_app(router));
    await _settle(tester);
  }

  testWidgets('QR venue → Campus Map pushes a back-capable route', (
    tester,
  ) async {
    final router = _router();
    await pumpApp(tester, router);
    expect(find.text('venue-abc'), findsOneWidget);

    await _openMap(tester);

    expect(router.state.uri.toString(), contains('/map'));
    expect(
      tester.element(find.byType(MapPage)).canPop(),
      isTrue,
      reason: 'the venue card must still be on the stack beneath the map',
    );
  });

  testWidgets('pushed map selects the marker and opens the detail panel', (
    tester,
  ) async {
    final router = _router();
    await pumpApp(tester, router);
    await _openMap(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapPage)),
    );
    expect(
      container.read(mapControllerProvider).value!.selectedBuilding?.code,
      '11WW',
    );
    expect(find.text("11 Wally's Walk"), findsOneWidget);
  });

  testWidgets('a back affordance is shown and returns to the venue', (
    tester,
  ) async {
    final router = _router();
    await pumpApp(tester, router);
    await _openMap(tester);

    final back = find.byIcon(Icons.arrow_back);
    expect(back, findsOneWidget, reason: 'pushed map must offer a way back');

    await tester.tap(back);
    await _settle(tester);

    expect(find.text('venue-abc'), findsOneWidget);
    expect(router.state.uri.toString(), '/location/abc');
  });

  testWidgets('returning preserves the venue card state', (tester) async {
    final router = _router();
    await pumpApp(tester, router);

    await tester.tap(find.text('add-to-my-day'));
    await _settle(tester);
    expect(find.text('added'), findsOneWidget);

    await _openMap(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);

    expect(
      find.text('added'),
      findsOneWidget,
      reason: 'the card was kept alive beneath the map, not rebuilt',
    );
  });

  testWidgets('repeated open/back cycles stay stable and do not stack up', (
    tester,
  ) async {
    final router = _router();
    await pumpApp(tester, router);

    for (var i = 0; i < 3; i++) {
      await _openMap(tester);
      expect(find.byType(MapPage), findsOneWidget, reason: 'cycle $i');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await _settle(tester);
      expect(find.text('venue-abc'), findsOneWidget, reason: 'cycle $i');
      expect(
        router.state.uri.toString(),
        '/location/abc',
        reason: 'cycle $i must return to a single venue route, not nest',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct/deep-link map entry shows no back affordance', (
    tester,
  ) async {
    // Cold start straight onto the map: nothing meaningful sits beneath it,
    // so offering "back" would strand the user on a dead control.
    final router = _router(initialLocation: '/map?building=11WW');
    await pumpApp(tester, router);
    await _settle(tester);

    expect(find.byType(MapPage), findsOneWidget);
    expect(tester.element(find.byType(MapPage)).canPop(), isFalse);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('replaceInShell policy leaves no back entry (unchanged flows)', (
    tester,
  ) async {
    // Home's suggested stops and the other in-shell entry points still use
    // `go`; this pins that the default policy was NOT switched to push.
    final router = GoRouter(
      initialLocation: '/from',
      routes: [
        GoRoute(
          path: '/from',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                // Default policy — no explicit argument.
                onPressed: () => openBuildingOnCampusMap(context, '11WW'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/map',
          name: RouteNames.map,
          builder: (context, state) => MapPage(
            initialBuildingId: state.uri.queryParameters['building'],
            showBackButton: state.uri.queryParameters['back'] == '1',
          ),
        ),
      ],
    );
    await pumpApp(tester, router);

    await tester.tap(find.text('go'));
    await _settle(tester);
    await _settle(tester);

    expect(find.byType(MapPage), findsOneWidget);
    expect(
      tester.element(find.byType(MapPage)).canPop(),
      isFalse,
      reason: 'default policy must still replace, not push',
    );
  });
}
