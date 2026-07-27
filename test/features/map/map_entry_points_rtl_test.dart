import 'dart:io';

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

/// Entry-point parity and RTL layout for the Campus Map.
///
/// Every flow that opens a building must land the user in the same place: the
/// right marker selected *and* its detail panel open. Locale and text
/// direction must not change any of that.

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

/// A deliberately long right-to-left name, to prove the panel does not clip.
final _longRtl = Building.fromJson({
  'id': 'long-rtl',
  'code': '14SCO',
  'name': 'ساختمان دانشکده علوم و مهندسی و مرکز پژوهش‌های پیشرفته دانشگاه',
  'location': {'lat': -33.776, 'lng': 151.114},
  'category': 'academic',
});

/// Hosts MapPage plus a second page that triggers the shared map command, so
/// every "open on map" entry point can be exercised the way it really runs.
Widget _app({Locale locale = const Locale('en'), required String openCode}) {
  final router = GoRouter(
    initialLocation: '/from',
    routes: [
      GoRoute(
        path: '/from',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openBuildingOnCampusMap(context, openCode),
              child: const Text('go'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/map',
        name: RouteNames.map,
        builder: (context, state) =>
            MapPage(initialBuildingId: state.uri.queryParameters['building']),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      mapRepositoryProvider.overrideWithValue(
        _FakeMapRepository([_wallys, _longRtl]),
      ),
      settingsControllerProvider.overrideWith(_FakeSettingsController.new),
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
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  /// The three product flows below (QR venue, suggested stop, Your Day
  /// session) all funnel through `openBuildingOnCampusMap`, so one
  /// parameterised body covers each of them faithfully.
  for (final flow in const ['QR venue', 'suggested stop', 'Your Day session']) {
    testWidgets('$flow → Campus Map selects the marker and opens the panel', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app(openCode: '11WW'));
      await _settle(tester);

      await tester.tap(find.text('go'));
      await _settle(tester);
      await _settle(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MapPage)),
      );
      expect(
        container.read(mapControllerProvider).value!.selectedBuilding?.code,
        '11WW',
        reason: '$flow must select the marker it navigated to',
      );
      expect(
        find.text("11 Wally's Walk"),
        findsOneWidget,
        reason: '$flow must open the location detail panel, not just centre',
      );
    });
  }

  testWidgets('a direct marker selection opens the detail panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(openCode: '11WW'));
    await _settle(tester);
    await tester.tap(find.text('go'));
    await _settle(tester);
    await _settle(tester);
    expect(find.text("11 Wally's Walk"), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapPage)),
    );
    // Close it, then select the marker again — the panel must come back.
    await tester.tap(find.byTooltip('Clear'));
    await _settle(tester);
    expect(find.text("11 Wally's Walk"), findsNothing);

    container.read(mapControllerProvider.notifier).selectBuilding(_wallys);
    await _settle(tester);
    expect(find.text("11 Wally's Walk"), findsOneWidget);
  });

  testWidgets('an unresolvable building shows no panel and does not crash', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // A code the registry does not know: the map must stay usable rather than
    // throw or present a stale panel.
    await tester.pumpWidget(_app(openCode: 'NOPE'));
    await _settle(tester);
    await tester.tap(find.text('go'));
    await _settle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapPage)),
    );
    expect(
      container.read(mapControllerProvider).value!.selectedBuilding,
      isNull,
    );
    expect(find.text("11 Wally's Walk"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('RTL layout', () {
    testWidgets('a long RTL title does not clip or overlap the close button', (
      tester,
    ) async {
      // Narrow phone width: the tightest case for a long right-to-left name.
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(locale: const Locale('fa'), openCode: '14SCO'),
      );
      await _settle(tester);
      await tester.tap(find.text('go'));
      await _settle(tester);
      await _settle(tester);

      expect(find.text(_longRtl.name), findsOneWidget);
      // No overflow anywhere in the panel.
      expect(tester.takeException(), isNull);

      // The close control stays inside the viewport and clear of the title.
      final close = tester.getRect(find.byTooltip('پاک کردن'));
      final title = tester.getRect(find.text(_longRtl.name));
      expect(close.width, greaterThan(0));
      expect(
        title.overlaps(close),
        isFalse,
        reason: 'a long title must not run under the close button',
      );
    });

    testWidgets('the panel keeps a usable height in RTL', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(locale: const Locale('fa'), openCode: '11WW'),
      );
      await _settle(tester);
      await tester.tap(find.text('go'));
      await _settle(tester);
      await _settle(tester);

      final title = tester.getRect(find.text("11 Wally's Walk"));
      expect(
        title.height,
        greaterThan(8),
        reason: 'the panel must not collapse to an unusable sliver in RTL',
      );
      expect(title.width, greaterThan(40));
    });

    testWidgets('narrow Persian rows render without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(locale: const Locale('fa'), openCode: '14SCO'),
      );
      await _settle(tester);
      await tester.tap(find.text('go'));
      await _settle(tester);
      await _settle(tester);

      expect(tester.takeException(), isNull);
    });
  });

  test('every map entry point routes through the shared command', () {
    // Guards the consolidation: a new flow that open-codes bump + select +
    // goNamed would drift out of step with the others (that is exactly how
    // the QR card ended up navigating without selecting a marker).
    const callers = [
      'lib/features/open_day/presentation/pages/your_day_page.dart',
      'lib/features/open_day/presentation/widgets/open_day_home_sections.dart',
      'lib/features/open_day/presentation/actions/open_event_venue.dart',
      'lib/features/scan/presentation/pages/location_card_page.dart',
    ];
    for (final path in callers) {
      final src = File(path).readAsStringSync();
      expect(
        src.contains('openBuildingOnCampusMap'),
        isTrue,
        reason: '$path should open the map via the shared command',
      );
      expect(
        src.contains('campusMapIntentProvider.notifier'),
        isFalse,
        reason: '$path should not re-implement the map-opening sequence',
      );
    }
  });
}
