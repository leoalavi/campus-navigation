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

/// Tapping a building in a category list must open its detail panel.
///
/// The regression these cover is subtle: the panel *was* built and the marker
/// *was* selected, so any `findsOneWidget` assertion passed — it was simply
/// rendered off the bottom of the screen. The category sheet's height settle
/// animation was still running when the footer flipped from the snappable
/// list to the non-snappable info card, and `_settle` drives a different
/// field in each mode, so a ~100px height was written into the card's
/// translation offset. These tests therefore assert on-screen geometry, not
/// mere existence.

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

Widget _app(Locale locale) {
  final router = GoRouter(
    initialLocation: '/map',
    routes: [
      GoRoute(
        path: '/map',
        name: RouteNames.map,
        builder: (c, s) =>
            MapPage(initialBuildingId: s.uri.queryParameters['building']),
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

void main() {
  for (final (locale, name) in const [
    (Locale('en'), 'en'),
    (Locale('fa'), 'fa/RTL'),
  ]) {
    testWidgets('$name: tapping a category row opens the panel on screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app(locale));
      await _settle(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MapPage)),
      );
      // 1. a category result list, the production entry point.
      container
          .read(mapControllerProvider.notifier)
          .updateSearchQuery('Building');
      await _settle(tester);
      expect(find.text('Building A'), findsOneWidget);
      expect(find.text('Building B'), findsOneWidget);

      // Tap it the way a user does — a real pointer sequence is what starts
      // the settle animation that used to corrupt the card's offset.
      await tester.tap(find.text('Building A'));
      await _settle(tester);

      // 4. the marker stays selected.
      expect(
        container.read(mapControllerProvider).value!.selectedBuilding?.code,
        'BLDA',
      );

      // 2. the category list is gone, replaced by the card.
      expect(find.text('Building B'), findsNothing);

      // 3 + 7. the panel is genuinely on screen, not pushed off the bottom
      // and not a zero-height sliver.
      final screen = tester.getSize(find.byType(MapPage));
      final panel = tester.getRect(find.text('Building A'));
      expect(
        panel.bottom,
        lessThanOrEqualTo(screen.height),
        reason: 'the detail panel must not render below the viewport',
      );
      expect(panel.top, greaterThanOrEqualTo(0));
      expect(panel.height, greaterThan(8));
      expect(panel.width, greaterThan(40));

      // 8. no framework or Riverpod exception.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('re-selecting the same building reopens the panel on screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(const Locale('en')));
    await _settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapPage)),
    );
    container
        .read(mapControllerProvider.notifier)
        .updateSearchQuery('Building');
    await _settle(tester);

    await tester.tap(find.text('Building A'));
    await _settle(tester);
    final screen = tester.getSize(find.byType(MapPage));
    expect(
      tester.getRect(find.text('Building A')).bottom,
      lessThanOrEqualTo(screen.height),
    );

    // 5. close it, select the same building again — it must come back, and
    // come back *visible*.
    await tester.tap(find.byTooltip('Clear'));
    await _settle(tester);
    expect(find.text('Building A'), findsNothing);

    container.read(mapControllerProvider.notifier).selectBuilding(_a);
    await _settle(tester);

    expect(find.text('Building A'), findsOneWidget);
    expect(
      tester.getRect(find.text('Building A')).bottom,
      lessThanOrEqualTo(screen.height),
    );
    expect(tester.takeException(), isNull);
  });
}
