import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/active_shell_branch_index_provider.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/map/presentation/pages/map_page.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

/// Back and Close are different actions, and leaving the Journey tab resets
/// the map's temporary exploration state.
///
/// Back pops one level to the list the detail was opened from; Close leaves
/// the whole panel flow. A detail reached directly (deep link / QR / Your Day)
/// has no list behind it, so it shows no Back at all.

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

Widget _app({
  Locale locale = const Locale('en'),
  bool pushedEntry = false,
  String? building,
}) {
  final router = GoRouter(
    initialLocation: '/map',
    routes: [
      GoRoute(
        path: '/map',
        name: RouteNames.map,
        builder: (_, _) =>
            MapPage(initialBuildingId: building, showBackButton: pushedEntry),
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

Future<ProviderContainer> _boot(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(MapPage)));
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MapPage)))!;

void main() {
  group('detail panel opened from a list', () {
    testWidgets('shows both Back and Close, and Back returns to the list', (
      tester,
    ) async {
      final c = await _boot(tester, _app());
      c.read(mapControllerProvider.notifier).updateSearchQuery('Building');
      await _settle(tester);
      expect(find.text('Building B'), findsOneWidget); // the list

      await tester.tap(find.text('Building A'));
      await _settle(tester);
      final l10n = _l10n(tester);

      // Both actions are present and visibly distinct.
      expect(find.byTooltip(l10n.back), findsOneWidget);
      expect(find.byTooltip(l10n.close), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.back));
      await _settle(tester);

      // Back one level: the results list is showing again.
      expect(find.text('Building B'), findsOneWidget);
      expect(
        c.read(mapControllerProvider).value!.searchQuery,
        'Building',
        reason: 'Back must not discard the list it returns to',
      );
    });

    testWidgets('Close hides the panel but keeps the destination pinned', (
      tester,
    ) async {
      // Close dismisses the panel and forgets the list that led there — but
      // the destination the user just looked up stays on the map. Wiping the
      // selection here made the marker vanish the instant the panel closed.
      final c = await _boot(tester, _app());
      c.read(mapControllerProvider.notifier).updateSearchQuery('Building');
      await _settle(tester);
      await tester.tap(find.text('Building A'));
      await _settle(tester);

      await tester.tap(find.byTooltip(_l10n(tester).close));
      await _settle(tester);

      final state = c.read(mapControllerProvider).value!;
      expect(
        state.selectedBuilding?.code,
        'BLDA',
        reason: 'the marker must survive closing its panel',
      );
      expect(state.searchQuery, isEmpty, reason: 'the list is forgotten');
      expect(
        find.text('Building B'),
        findsNothing,
        reason: 'Close must not fall back to the list — that is Back\'s job',
      );
      // The panel itself is gone.
      expect(find.byTooltip(_l10n(tester).close), findsNothing);
    });

    testWidgets('fa/RTL: Back and Close are both usable', (tester) async {
      final c = await _boot(tester, _app(locale: const Locale('fa')));
      c.read(mapControllerProvider.notifier).updateSearchQuery('Building');
      await _settle(tester);
      await tester.tap(find.text('Building A'));
      await _settle(tester);
      final l10n = _l10n(tester);

      // The back glyph mirrors; the close cross never does.
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.close), findsWidgets);

      await tester.tap(find.byTooltip(l10n.back));
      await _settle(tester);
      expect(find.text('Building B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a detail opened directly shows no Back button', (tester) async {
    // Deep link / QR / Your Day: there is no list behind it, so a Back button
    // would have nowhere to go.
    await _boot(tester, _app(building: 'BLD-A'));
    await _settle(tester);
    final l10n = _l10n(tester);

    expect(find.text('Building A'), findsOneWidget);
    expect(find.byTooltip(l10n.back), findsNothing);
    expect(find.byTooltip(l10n.close), findsOneWidget);
  });

  group('leaving the Journey tab', () {
    testWidgets('resets category, selection and search', (tester) async {
      final c = await _boot(tester, _app());
      c.read(mapControllerProvider.notifier).updateSearchQuery('Building');
      await _settle(tester);
      await tester.tap(find.text('Building A'));
      await _settle(tester);
      expect(c.read(mapControllerProvider).value!.selectedBuilding, isNotNull);

      // Switch away via bottom navigation, then come back.
      c
          .read(activeShellBranchIndexProvider.notifier)
          .setIndex(ShellBranchIndex.map);
      await _settle(tester);
      c.read(activeShellBranchIndexProvider.notifier).setIndex(0);
      await _settle(tester);
      c
          .read(activeShellBranchIndexProvider.notifier)
          .setIndex(ShellBranchIndex.map);
      await _settle(tester);

      final state = c.read(mapControllerProvider).value!;
      expect(state.selectedBuilding, isNull, reason: 'no stale selection');
      expect(state.searchQuery, isEmpty, reason: 'no stale search');
      expect(state.selectedFacultyGroup, isNull);
      expect(state.error, isNull, reason: 'no stale status message');
      expect(find.text('Building B'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a pushed QR/Your Day entry keeps its selection', (
      tester,
    ) async {
      // The selection is the reason the map was pushed; wiping it on a tab
      // switch would strand the user when they press Back.
      final c = await _boot(tester, _app(pushedEntry: true, building: 'BLD-A'));
      await _settle(tester);
      expect(c.read(mapControllerProvider).value!.selectedBuilding, isNotNull);

      c
          .read(activeShellBranchIndexProvider.notifier)
          .setIndex(ShellBranchIndex.map);
      await _settle(tester);
      c.read(activeShellBranchIndexProvider.notifier).setIndex(0);
      await _settle(tester);

      expect(
        c.read(mapControllerProvider).value!.selectedBuilding?.code,
        'BLDA',
        reason: 'a pushed detour must survive a tab switch',
      );
    });

    testWidgets('repeated tab switching leaks no state', (tester) async {
      final c = await _boot(tester, _app());
      for (var i = 0; i < 3; i++) {
        c.read(mapControllerProvider.notifier).updateSearchQuery('Building');
        await _settle(tester);
        c
            .read(activeShellBranchIndexProvider.notifier)
            .setIndex(ShellBranchIndex.map);
        await _settle(tester);
        c.read(activeShellBranchIndexProvider.notifier).setIndex(2);
        await _settle(tester);
        expect(
          c.read(mapControllerProvider).value!.searchQuery,
          isEmpty,
          reason: 'cycle $i should have reset',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a tab switch clears map state without navigating', (
    tester,
  ) async {
    // The bug this pins: clearing exploration state nulled the selection, the
    // map's state->URL listener saw a stale `?building=` query and fired
    // `goNamed('/map')`, and the router yanked the user back to Journey. The
    // reset must be silent.
    final c = await _boot(tester, _app());
    c.read(mapControllerProvider.notifier).updateSearchQuery('Building');
    await _settle(tester);
    await tester.tap(find.text('Building A'));
    await _settle(tester);

    final router = GoRouter.of(tester.element(find.byType(MapPage)));
    final before = router.routeInformationProvider.value.uri.toString();

    // Simulate the shell telling the map it is no longer the visible branch.
    c
        .read(activeShellBranchIndexProvider.notifier)
        .setIndex(ShellBranchIndex.map);
    await _settle(tester);
    c.read(activeShellBranchIndexProvider.notifier).setIndex(0);
    await _settle(tester);

    // State cleared...
    final state = c.read(mapControllerProvider).value!;
    expect(state.selectedBuilding, isNull);
    expect(state.searchQuery, isEmpty);
    // ...and nothing navigated on the way.
    expect(
      router.routeInformationProvider.value.uri.toString(),
      before,
      reason: 'clearing map state must not push or replace a route',
    );
    expect(tester.takeException(), isNull);
  });
}
