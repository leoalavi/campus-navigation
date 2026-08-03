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
import 'package:mq_journey/features/map/presentation/pages/map_page.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

/// The location status banner must stay readable over the map.
///
/// It previously used an error tint at 0.14 alpha in dark mode, so the campus
/// map showed straight through the one message the user needs when location
/// fails. These tests pin the surface to an opaque one in both themes and
/// check each location state produces its own copy and action.

class _FakeSettings extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

class _FakeRepo implements MapRepository {
  _FakeRepo(this.permission);
  final LocationPermissionState permission;

  var openedAppSettings = 0;
  var openedLocationSettings = 0;

  @override
  Future<List<Building>> getBuildings({bool forceRefresh = false}) async => [
    Building.fromJson({
      'id': 'BLD-A',
      'code': 'BLDA',
      'name': 'Building A',
      'location': {'lat': -33.775, 'lng': 151.113},
      'category': 'academic',
    }),
  ];
  @override
  Future<LocationPermissionState> ensureLocationPermission() async =>
      permission;
  @override
  Future<LocationSample?> getCurrentLocation() async => null;
  @override
  Stream<LocationSample> watchLocation() => const Stream.empty();
  @override
  Future<void> openAppSettings() async => openedAppSettings++;
  @override
  Future<void> openLocationSettings() async => openedLocationSettings++;
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

Future<_FakeRepo> _boot(
  WidgetTester tester,
  LocationPermissionState permission, {
  Brightness brightness = Brightness.dark,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = _FakeRepo(permission);
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapRepositoryProvider.overrideWithValue(repo),
        settingsControllerProvider.overrideWith(_FakeSettings.new),
      ],
      child: MaterialApp.router(
        theme: ThemeData(brightness: brightness),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return repo;
}

/// Taps the pink My Location button — the action that surfaces the banner,
/// and exactly what the user does when location is off.
Future<void> _tapMyLocation(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.my_location));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The banner's own surface — the Container holding the warning icon.
Color _bannerColour(WidgetTester tester) {
  final box = tester.widget<Container>(
    find
        .ancestor(
          of: find.byIcon(Icons.warning_amber_rounded),
          matching: find.byType(Container),
        )
        .first,
  );
  return ((box.decoration! as BoxDecoration).color)!;
}

void main() {
  for (final (brightness, name) in const [
    (Brightness.dark, 'dark'),
    (Brightness.light, 'light'),
  ]) {
    testWidgets('$name: the status surface is opaque, not see-through', (
      tester,
    ) async {
      await _boot(
        tester,
        LocationPermissionState.servicesDisabled,
        brightness: brightness,
      );
      await _tapMyLocation(tester);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(
        _bannerColour(tester).a,
        greaterThanOrEqualTo(0.95),
        reason:
            'location errors must not be read through the map — the dark '
            'theme previously used a 0.14-alpha tint',
      );
    });
  }

  testWidgets('services disabled offers a settings action that works', (
    tester,
  ) async {
    final repo = await _boot(tester, LocationPermissionState.servicesDisabled);
    await _tapMyLocation(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(MapPage)))!;

    expect(find.text(l10n.locationServicesDisabled), findsOneWidget);
    await tester.tap(find.text(l10n.settings));
    await tester.pump();
    expect(
      repo.openedLocationSettings,
      1,
      reason: 'a disabled *service* opens location settings, not app settings',
    );
  });

  testWidgets('permission denied shows its own copy and app settings', (
    tester,
  ) async {
    final repo = await _boot(tester, LocationPermissionState.denied);
    await _tapMyLocation(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(MapPage)))!;

    expect(find.text(l10n.locationPermissionRequired), findsOneWidget);
    await tester.tap(find.text(l10n.settings));
    await tester.pump();
    expect(repo.openedAppSettings, 1);
  });

  testWidgets('permanently denied is distinguished from a plain denial', (
    tester,
  ) async {
    await _boot(tester, LocationPermissionState.deniedForever);
    await _tapMyLocation(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(MapPage)))!;

    expect(find.text(l10n.locationPermissionBlocked), findsOneWidget);
    expect(
      find.text(l10n.locationPermissionRequired),
      findsNothing,
      reason: 'blocked and merely-denied must not show the same message',
    );
  });

  testWidgets(
    'granted but no fix reports "unavailable", not a permission problem',
    (tester) async {
      // A distinct fifth state: permission is fine, the device simply could not
      // produce a position. It must not be reported as a permission failure,
      // and it offers no settings action because settings cannot fix it.
      await _boot(tester, LocationPermissionState.granted);
      await _tapMyLocation(tester);
      final l10n = AppLocalizations.of(tester.element(find.byType(MapPage)))!;

      expect(find.text(l10n.locationUnavailable), findsOneWidget);
      expect(find.text(l10n.locationPermissionRequired), findsNothing);
      expect(find.text(l10n.locationServicesDisabled), findsNothing);
      expect(find.text(l10n.settings), findsNothing);
    },
  );

  testWidgets('the banner does not cover the map controls', (tester) async {
    await _boot(tester, LocationPermissionState.servicesDisabled);
    await _tapMyLocation(tester);
    final banner = tester.getRect(find.byIcon(Icons.warning_amber_rounded));
    final locate = tester.getRect(find.byIcon(Icons.my_location));
    expect(
      banner.overlaps(locate),
      isFalse,
      reason: 'the status message must not sit on top of My Location',
    );
  });
}
