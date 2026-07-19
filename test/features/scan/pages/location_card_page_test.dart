import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/scan/application/pending_stamp_award_controller.dart';
import 'package:mq_journey/features/scan/domain/contracts/location_content.dart';
import 'package:mq_journey/features/scan/domain/contracts/schedule_provider.dart';
import 'package:mq_journey/features/scan/domain/contracts/schedule_slot.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_my_day_api.dart';
import 'package:mq_journey/features/scan/domain/models/buildings_registry.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/presentation/pages/location_card_page.dart';
import 'package:mq_journey/features/scan/presentation/widgets/photo_gallery.dart';
import 'package:mq_journey/features/scan/presentation/widgets/open_day_stops_table.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_earned_sheet.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/settings/data/repositories/settings_repository.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/misc.dart' show Override;

class _NoSchedule implements ScheduleProvider {
  @override
  ScheduleSlot? liveNow(String id) => null;
  @override
  ScheduleSlot? comingUpNext(String id) => null;
}

class MockSettingsRepository extends Mock implements SettingsRepository {}

// MaterialApp + router only; overrides are supplied by wrapping in ProviderScope
// at each call site (keeps the Riverpod Override type inferred, never named).
Widget _app() {
  final router = GoRouter(
    initialLocation: '/location/wallys-1',
    routes: [
      GoRoute(
        path: '/location/:locationId',
        builder: (_, s) =>
            LocationCardPage(locationId: s.pathParameters['locationId']!),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  const trail = TrailManifest(
    locations: [
      TrailLocation(
        locationId: 'wallys-1',
        buildingId: 'wallys-1',
        title: '1 Wally\'s Walk',
        photos: ['assets/photos/_placeholder.jpg'],
        arSceneId: 'entrance',
        stops: [
          OpenDayStop(
            stopId: 'wallys-1-g03',
            title: 'Theatre G03',
            arSceneId: 'theatre-g03',
          ),
        ],
      ),
    ],
  );

  const registry = BuildingsRegistry(
    buildings: [
      BuildingEntry(
        code: 'wallys-1',
        name: '1 Wally\'s Walk',
        campusX: 0,
        campusY: 0,
        entranceLatitude: -33.7747,
        entranceLongitude: 151.1142,
      ),
    ],
  );

  // Inferred return type is List<Override> — never named explicitly.
  List<Override> baseOverrides({
    String? scheduleUrl,
    bool overrideVisitedState = true,
  }) => [
    trailManifestProvider.overrideWith((ref) async => trail),
    buildingsRegistryProvider.overrideWith((ref) async => registry),
    locationContentProvider.overrideWith(
      (ref, id) => LocationContent(
        locationId: id,
        title: '1 Wally\'s Walk',
        heroImageAsset: 'assets/images/placeholder_hero.png',
        shortDescription: 'One. Two. Three.',
        buildingId: 'wallys-1',
        fullScheduleUrl: scheduleUrl,
      ),
    ),
    scheduleProvider.overrideWith((ref) => _NoSchedule()),
    if (overrideVisitedState)
      visitedStateProvider.overrideWith(
        (ref, id) => Stream.value(
          const VisitedState(visited: false, rewardEarned: false),
        ),
      ),
    myDayApiProvider.overrideWith((ref) => FakeMyDayApi()),
  ];

  testWidgets('renders gallery, 3-sentence read, primary buttons; no stops '
      'table (duplicate AR row removed)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: baseOverrides(), child: _app()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PhotoGallery), findsOneWidget);
    expect(find.text('One. Two. Three.'), findsOneWidget);
    expect(find.text('View on Campus Map'), findsOneWidget);
    expect(find.text('View AR map'), findsOneWidget);
    // The per-scene "stops" list (e.g. "Theatre G03") is intentionally gone
    // from the venue card — scene selection lives inside the AR viewer.
    expect(find.byType(OpenDayStopsTable), findsNothing);
    expect(find.text('Theatre G03'), findsNothing);
    // Simple venue card: Add to Your Day present, no full-schedule link.
    expect(find.text('Add to Your Day'), findsOneWidget);
    expect(find.text('Full schedule'), findsNothing); // fullScheduleUrl null
  });

  testWidgets('hides AR button when no scene anywhere', (tester) async {
    const t = TrailManifest(
      locations: [
        TrailLocation(
          locationId: 'wallys-1',
          buildingId: 'wallys-1',
          title: 'x',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trailManifestProvider.overrideWith((ref) async => t),
          ...baseOverrides().skip(1),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('View AR map'), findsNothing);
  });

  testWidgets('Campus Map button disabled when building not in registry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trailManifestProvider.overrideWith((ref) async => trail),
          buildingsRegistryProvider.overrideWith((ref) async => registry),
          locationContentProvider.overrideWith(
            (ref, id) => LocationContent(
              locationId: id,
              title: 'x',
              heroImageAsset: 'assets/images/placeholder_hero.png',
              shortDescription: 'One. Two. Three.',
              buildingId: 'not-in-registry', // absent from registry
            ),
          ),
          scheduleProvider.overrideWith((ref) => _NoSchedule()),
          visitedStateProvider.overrideWith(
            (ref, id) => Stream.value(
              const VisitedState(visited: false, rewardEarned: false),
            ),
          ),
          myDayApiProvider.overrideWith((ref) => FakeMyDayApi()),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'View on Campus Map'),
    );
    expect(button.onPressed, isNull); // disabled — never opens an empty map
  });

  testWidgets('shows visited badge after scan state is stored uppercase', (
    tester,
  ) async {
    final mockRepo = MockSettingsRepository();
    when(() => mockRepo.loadPreferences()).thenAnswer(
      (_) async => const UserPreferences(visitedLocationCodes: ['WALLYS-1']),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockRepo),
          ...baseOverrides(overrideVisitedState: false),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visited'), findsOneWidget);
  });

  testWidgets('consumes a pending first visit once on the location card', (
    tester,
  ) async {
    final mockRepo = MockSettingsRepository();
    when(() => mockRepo.loadPreferences()).thenAnswer(
      (_) async => const UserPreferences(visitedLocationCodes: ['WALLYS-1']),
    );
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(mockRepo),
        stampCatalogProvider.overrideWith(
          (ref) async => const [
            StampCatalogEntry(
              locationId: 'wallys-1',
              title: "1 Wally's Walk",
              mapRef: 'K27',
              stampAsset: 'assets/stamps/wallys-1.png',
            ),
          ],
        ),
        ...baseOverrides(),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(pendingStampAwardProvider.notifier)
        .setNotice(
          const PendingStampNotice(locationId: 'wallys-1', isNewVisit: true),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _app()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(StampEarnedSheet), findsOneWidget);
    expect(container.read(pendingStampAwardProvider), isNull);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StampEarnedSheet)),
    )!;
    await tester.tap(find.text(l10n.stampCelebrationKeepExploring));
    await tester.pumpAndSettle();
    expect(find.byType(StampEarnedSheet), findsNothing);
  });

  testWidgets(
    'Campus Map button navigates with mapBuildingCode, not the trail slug',
    (tester) async {
      // The registry holds BOTH the coordinate-less trail stub ("wallys-29")
      // and the real placed building ("29WW"). The button must open the map on
      // the real code so the camera focuses the building, not the (0,0) corner.
      String? capturedBuilding;
      final router = GoRouter(
        initialLocation: '/location/wallys-29',
        routes: [
          GoRoute(
            path: '/location/:locationId',
            builder: (_, s) =>
                LocationCardPage(locationId: s.pathParameters['locationId']!),
          ),
          GoRoute(
            name: RouteNames.map,
            path: '/map',
            builder: (_, s) {
              capturedBuilding = s.uri.queryParameters['building'];
              return const Scaffold(body: Text('MAP'));
            },
          ),
        ],
      );

      const twoBuildingRegistry = BuildingsRegistry(
        buildings: [
          BuildingEntry(
            code: 'wallys-29', // Open Day stub — no coords
            name: "29 Wally's Walk",
            campusX: 0,
            campusY: 0,
            entranceLatitude: 0,
            entranceLongitude: 0,
          ),
          BuildingEntry(
            code: '29WW', // real placed building
            name: "29 Wally's Walk (Faculty of Arts)",
            campusX: 1496,
            campusY: 1875,
            entranceLatitude: -33.774,
            entranceLongitude: 151.1135,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trailManifestProvider.overrideWith(
              (ref) async => const TrailManifest(
                locations: [
                  TrailLocation(
                    locationId: 'wallys-29',
                    buildingId: 'wallys-29',
                    mapBuildingCode: '29WW',
                    title: "29 Wally's Walk",
                  ),
                ],
              ),
            ),
            buildingsRegistryProvider.overrideWith(
              (ref) async => twoBuildingRegistry,
            ),
            locationContentProvider.overrideWith(
              (ref, id) => const LocationContent(
                locationId: 'wallys-29',
                title: "29 Wally's Walk",
                heroImageAsset: 'assets/images/placeholder_hero.png',
                shortDescription: 'One. Two. Three.',
                buildingId: 'wallys-29',
                mapBuildingCode: '29WW',
              ),
            ),
            scheduleProvider.overrideWith((ref) => _NoSchedule()),
            visitedStateProvider.overrideWith(
              (ref, id) => Stream.value(
                const VisitedState(visited: false, rewardEarned: false),
              ),
            ),
            myDayApiProvider.overrideWith((ref) => FakeMyDayApi()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'View on Campus Map'),
      );
      expect(button.onPressed, isNotNull); // enabled (29WW resolves)

      final mapButton = find.widgetWithText(
        OutlinedButton,
        'View on Campus Map',
      );
      await tester.ensureVisible(mapButton);
      await tester.tap(mapButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(capturedBuilding, '29WW'); // real code, not "wallys-29"
    },
  );

  testWidgets('Full schedule link shows when fullScheduleUrl is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(scheduleUrl: 'https://mq.edu.au/openday'),
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Full schedule'), findsOneWidget);
  });
}
