import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/domain/services/map_back_action.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/map/presentation/pages/map_page.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

/// The platform Back (Android button, browser history, iOS edge swipe) must
/// step through the map's panel hierarchy exactly like the on-screen Back,
/// and must still pop the route when there is nothing temporary to dismiss.

class _FakeSettings extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

class _FakeRepo implements MapRepository {
  _FakeRepo(
    this.buildings, {
    this.permission = LocationPermissionState.granted,
  });
  final List<Building> buildings;
  final LocationPermissionState permission;
  @override
  Future<List<Building>> getBuildings({bool forceRefresh = false}) async =>
      buildings;
  @override
  Future<LocationPermissionState> ensureLocationPermission() async =>
      permission;
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

/// Delivers a real platform back gesture, the way Android/the browser do.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// A source page that *pushes* the map, mirroring QR / Your Day entries.
Widget _app({
  Locale locale = const Locale('en'),
  LocationPermissionState permission = LocationPermissionState.granted,
  String sourceLabel = 'source-page',
}) {
  final router = GoRouter(
    initialLocation: '/source',
    routes: [
      GoRoute(
        path: '/source',
        builder: (context, _) => Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => context.pushNamed(
                RouteNames.map,
                queryParameters: {'building': 'BLDA', 'back': '1'},
              ),
              child: Text(sourceLabel),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/map',
        name: RouteNames.map,
        builder: (_, s) => MapPage(
          initialBuildingId: s.uri.queryParameters['building'],
          showBackButton: s.uri.queryParameters['back'] == '1',
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      mapRepositoryProvider.overrideWithValue(
        _FakeRepo([_a, _b], permission: permission),
      ),
      settingsControllerProvider.overrideWith(_FakeSettings.new),
    ],
    child: MaterialApp.router(
      locale: locale,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<ProviderContainer> _openMap(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await _settle(tester);
  await tester.tap(find.text('source-page'));
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(MapPage)));
}

void main() {
  group('precedence rules', () {
    test('peels exactly one layer, outermost first', () {
      expect(
        mapBackAction(
          hasStatusMessage: true,
          hasSelectionFromList: true,
          hasSubgroup: true,
          hasCategoryPanel: true,
        ),
        MapBackAction.dismissStatusMessage,
      );
      expect(
        mapBackAction(
          hasStatusMessage: false,
          hasSelectionFromList: true,
          hasSubgroup: true,
          hasCategoryPanel: true,
        ),
        MapBackAction.closeLocationDetail,
      );
      expect(
        mapBackAction(
          hasStatusMessage: false,
          hasSelectionFromList: false,
          hasSubgroup: true,
          hasCategoryPanel: true,
        ),
        MapBackAction.closeSubgroup,
      );
      expect(
        mapBackAction(
          hasStatusMessage: false,
          hasSelectionFromList: false,
          hasSubgroup: false,
          hasCategoryPanel: true,
        ),
        MapBackAction.closeCategoryPanel,
      );
      expect(
        mapBackAction(
          hasStatusMessage: false,
          hasSelectionFromList: false,
          hasSubgroup: false,
          hasCategoryPanel: false,
        ),
        MapBackAction.popRoute,
      );
    });

    test('a detail with no list behind it falls through to a route pop', () {
      // Deep link / QR / Your Day: Back belongs to the source page.
      expect(
        mapBackAction(
          hasStatusMessage: false,
          hasSelectionFromList: false,
          hasSubgroup: false,
          hasCategoryPanel: false,
        ),
        MapBackAction.popRoute,
      );
    });
  });

  testWidgets('1. system Back dismisses the location message first', (
    tester,
  ) async {
    final c = await _openMap(
      tester,
      _app(permission: LocationPermissionState.servicesDisabled),
    );
    await tester.tap(find.byIcon(Icons.my_location));
    await _settle(tester);
    expect(c.read(mapControllerProvider).value!.error, isNotNull);

    await _systemBack(tester);

    expect(c.read(mapControllerProvider).value!.error, isNull);
    expect(find.byType(MapPage), findsOneWidget, reason: 'still on the map');
  });

  testWidgets('2-4. system Back steps down the panel hierarchy', (
    tester,
  ) async {
    final c = await _openMap(tester, _app());
    final n = c.read(mapControllerProvider.notifier);
    n.updateSearchQuery('Building');
    await _settle(tester);
    n.selectBuilding(_a);
    await _settle(tester);

    // 2. detail → list
    await _systemBack(tester);
    expect(c.read(mapControllerProvider).value!.selectedBuilding, isNull);
    expect(c.read(mapControllerProvider).value!.searchQuery, 'Building');
    expect(find.text('Building B'), findsOneWidget);

    // 4. root panel → plain map
    await _systemBack(tester);
    expect(c.read(mapControllerProvider).value!.searchQuery, isEmpty);
    expect(find.byType(MapPage), findsOneWidget);

    // 5. clean map → the route itself pops, back to the source page
    await _systemBack(tester);
    expect(find.text('source-page'), findsOneWidget);
  });

  testWidgets('3. system Back leaves a subgroup for its category', (
    tester,
  ) async {
    final c = await _openMap(tester, _app());
    final n = c.read(mapControllerProvider.notifier);
    n.updateSearchQuery('Faculty');
    await _settle(tester);
    n.selectFacultyGroup(FacultyGroup.values.first);
    await _settle(tester);
    expect(
      c.read(mapControllerProvider).value!.selectedFacultyGroup,
      isNotNull,
    );

    await _systemBack(tester);

    expect(c.read(mapControllerProvider).value!.selectedFacultyGroup, isNull);
    expect(
      c.read(mapControllerProvider).value!.searchQuery,
      'Faculty',
      reason: 'the parent category stays open',
    );
  });

  testWidgets('6/7. a pushed QR / Your Day entry returns to its source', (
    tester,
  ) async {
    // Only the pushed detail is showing — no list — so Back belongs to the
    // page that pushed the map.
    await _openMap(tester, _app());
    expect(find.byType(MapPage), findsOneWidget);

    await _systemBack(tester);

    expect(
      find.text('source-page'),
      findsOneWidget,
      reason: 'a pushed detour must return to exactly where it came from',
    );
  });

  testWidgets('9. Persian RTL behaves identically to English', (tester) async {
    final c = await _openMap(tester, _app(locale: const Locale('fa')));
    final n = c.read(mapControllerProvider.notifier);
    n.updateSearchQuery('Building');
    await _settle(tester);
    n.selectBuilding(_a);
    await _settle(tester);

    await _systemBack(tester);
    expect(c.read(mapControllerProvider).value!.selectedBuilding, isNull);
    expect(c.read(mapControllerProvider).value!.searchQuery, 'Building');

    await _systemBack(tester);
    expect(c.read(mapControllerProvider).value!.searchQuery, isEmpty);

    await _systemBack(tester);
    expect(find.text('source-page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('10. repeated Back never loops or strands the user', (
    tester,
  ) async {
    final c = await _openMap(tester, _app());
    final n = c.read(mapControllerProvider.notifier);
    n.updateSearchQuery('Building');
    await _settle(tester);
    n.selectBuilding(_a);
    await _settle(tester);

    // Far more presses than there are layers: it must terminate on the
    // source page rather than cycling or trapping.
    for (var i = 0; i < 6; i++) {
      await _systemBack(tester);
    }
    expect(find.text('source-page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
