import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/home/presentation/pages/home_page.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/features/transit/domain/entities/metro_departure.dart';
import 'package:mq_journey/features/transit/presentation/providers/tfnsw_provider.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';
import 'package:mq_journey/shared/widgets/open_day_wordmark.dart';

class _FakeSettingsController extends SettingsController {
  final UserPreferences _prefs = const UserPreferences();

  @override
  Future<UserPreferences> build() async => _prefs;
}

class _FakeMapController extends MapController {
  @override
  Future<MapState> build() async {
    return const MapState(buildings: <Building>[], searchResults: <Building>[]);
  }
}

Widget _app({required GoRouter router}) {
  return ProviderScope(
    overrides: [
      settingsControllerProvider.overrideWith(() => _FakeSettingsController()),
      mapControllerProvider.overrideWith(() => _FakeMapController()),
      tfnswMetroProvider.overrideWith(
        (ref) => Stream.value(const <MetroDeparture>[]),
      ),
      selectedBachelorProvider.overrideWithValue(null),
      openDayDataProvider.overrideWith(
        (ref) async => OpenDayData(
          openDayDate: DateTime(2026, 8, 22),
          lastUpdated: DateTime.now(),
          studyAreas: const [],
          bachelors: const [],
          events: const [],
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

GoRouter _routerWithHome({
  required Widget Function() extraRouteBody,
  required String extraPath,
}) {
  // Mirrors production's branch order (Home=0, Map=1, Scan=2, Settings=3) so
  // that ShellBranchIndex.scan resolves to extraPath exactly like it does in
  // the real app_router.dart — the Home CTA now switches tabs via
  // StatefulNavigationShell.of(context).goBranch(), which requires a real
  // shell ancestor to exist.
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => navigationShell,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (_, _) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map-placeholder',
                builder: (_, _) =>
                    const Scaffold(body: Text('map-placeholder')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: extraPath,
                name: extraPath.replaceAll('/', ''),
                builder: (_, _) => extraRouteBody(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings-placeholder',
                builder: (_, _) =>
                    const Scaffold(body: Text('settings-placeholder')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  setUpAll(() => tz.initializeTimeZones());

  testWidgets('renders the welcome hero and quick access section', (
    tester,
  ) async {
    final router = _routerWithHome(
      extraPath: '/scan',
      extraRouteBody: () => const Scaffold(body: Text('scan-page')),
    );

    await tester.pumpWidget(_app(router: router));
    await tester.pump(const Duration(milliseconds: 700));

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)))!;
    // The hero now carries the Open Day 2026 identity (wordmark banner)
    // instead of the standard app-name welcome title.
    expect(find.byType(OpenDayWordmark), findsOneWidget);
    expect(find.text(l10n.home_welcomeSubtitle), findsOneWidget);
    expect(find.text(l10n.home_quickAccess.toUpperCase()), findsOneWidget);
  });

  testWidgets('tapping the scan CTA navigates to /scan', (tester) async {
    final router = _routerWithHome(
      extraPath: '/scan',
      extraRouteBody: () => const Scaffold(body: Text('scan-page')),
    );

    await tester.pumpWidget(_app(router: router));
    await tester.pump(const Duration(milliseconds: 700));

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)))!;
    await tester.tap(find.text(l10n.home_scanQrCta));
    await tester.pumpAndSettle();

    expect(find.text('scan-page'), findsOneWidget);
  });

  testWidgets('tapping a Quick Access tile navigates to Map', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, _) => const HomePage(),
        ),
        GoRoute(
          path: '/map',
          name: 'map',
          builder: (_, _) => const Scaffold(body: Text('map-page')),
        ),
      ],
    );

    await tester.pumpWidget(_app(router: router));
    await tester.pump(const Duration(milliseconds: 700));

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)))!;
    await tester.scrollUntilVisible(
      find.text(l10n.home_studentServices),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text(l10n.home_studentServices));
    await tester.pumpAndSettle();

    expect(find.text('map-page'), findsOneWidget);
  });
}
