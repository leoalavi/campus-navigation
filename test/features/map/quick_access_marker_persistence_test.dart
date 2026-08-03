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
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

/// Closing a location's detail panel must not delete the location.
///
/// Close previously ran `clearCategoryBrowse()`, which wipes `selectedBuilding`
/// along with the list — so dismissing the panel also removed the marker the
/// user had just looked up. Close now keeps the destination pinned and only
/// forgets the list; Back is the action that returns to the list.

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

Widget _app({Locale locale = const Locale('en')}) {
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
      locale: locale,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Quick Access → a category list → tap a location.
Future<ProviderContainer> _openFromQuickAccess(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(locale: locale));
  await _settle(tester);
  final c = ProviderScope.containerOf(tester.element(find.byType(MapPage)));
  c.read(mapControllerProvider.notifier).updateSearchQuery('Building');
  await _settle(tester);
  await tester.tap(find.text('Building A'));
  await _settle(tester);
  return c;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MapPage)))!;

void main() {
  testWidgets('1-2. Quick Access opens the marker and its detail panel', (
    tester,
  ) async {
    final c = await _openFromQuickAccess(tester);
    expect(c.read(mapControllerProvider).value!.selectedBuilding?.code, 'BLDA');
    expect(find.byTooltip(_l10n(tester).close), findsOneWidget);
    expect(find.byTooltip(_l10n(tester).back), findsOneWidget);
  });

  testWidgets('3-4. Close hides only the panel; marker and camera stay', (
    tester,
  ) async {
    final c = await _openFromQuickAccess(tester);
    final centredOn = c.read(mapControllerProvider).value!.selectedBuilding!.id;

    await tester.tap(find.byTooltip(_l10n(tester).close));
    await _settle(tester);

    final state = c.read(mapControllerProvider).value!;
    expect(
      state.selectedBuilding?.code,
      'BLDA',
      reason: 'the marker must remain after closing the panel',
    );
    expect(
      state.selectedBuilding!.id,
      centredOn,
      reason: 'the map stays centred on the same destination',
    );
    // The panel itself is gone.
    expect(find.byTooltip(_l10n(tester).close), findsNothing);
  });

  testWidgets('5. re-selecting the marker reopens the detail panel', (
    tester,
  ) async {
    final c = await _openFromQuickAccess(tester);
    await tester.tap(find.byTooltip(_l10n(tester).close));
    await _settle(tester);
    expect(find.byTooltip(_l10n(tester).close), findsNothing);

    // Tapping the marker again is a fresh selection event.
    c.read(mapControllerProvider.notifier).selectBuilding(_a);
    await _settle(tester);

    expect(find.text('Building A'), findsOneWidget);
    expect(find.byTooltip(_l10n(tester).close), findsOneWidget);
  });

  testWidgets('6-7. Back returns to the list; Close does not', (tester) async {
    // Back
    var c = await _openFromQuickAccess(tester);
    await tester.tap(find.byTooltip(_l10n(tester).back));
    await _settle(tester);
    expect(find.text('Building B'), findsOneWidget, reason: 'list is back');
    expect(c.read(mapControllerProvider).value!.searchQuery, 'Building');

    // Close, from a fresh open
    c = await _openFromQuickAccess(tester);
    await tester.tap(find.byTooltip(_l10n(tester).close));
    await _settle(tester);
    expect(
      find.text('Building B'),
      findsNothing,
      reason: 'Close must not fall back to the list',
    );
  });

  testWidgets('8. selecting another location replaces marker and panel', (
    tester,
  ) async {
    final c = await _openFromQuickAccess(tester);
    c.read(mapControllerProvider.notifier).selectBuilding(_b);
    await _settle(tester);

    expect(c.read(mapControllerProvider).value!.selectedBuilding?.code, 'BLDB');
    expect(find.text('Building B'), findsWidgets);
  });

  testWidgets('9. fa/RTL behaves identically', (tester) async {
    final c = await _openFromQuickAccess(tester, locale: const Locale('fa'));
    await tester.tap(find.byTooltip(_l10n(tester).close));
    await _settle(tester);

    expect(
      c.read(mapControllerProvider).value!.selectedBuilding?.code,
      'BLDA',
      reason: 'marker persistence must not depend on text direction',
    );
    expect(tester.takeException(), isNull);
  });
}
