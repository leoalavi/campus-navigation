import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/contracts/location_content.dart';
import 'package:mq_journey/features/scan/domain/contracts/schedule_provider.dart';
import 'package:mq_journey/features/scan/domain/contracts/schedule_slot.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_my_day_api.dart';
import 'package:mq_journey/features/scan/domain/models/buildings_registry.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/presentation/pages/location_card_page.dart';
import 'package:mq_journey/features/scan/presentation/widgets/photo_gallery.dart';
import 'package:mq_journey/features/scan/presentation/widgets/open_day_stops_table.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';

class _NoSchedule implements ScheduleProvider {
  @override
  ScheduleSlot? liveNow(String id) => null;
  @override
  ScheduleSlot? comingUpNext(String id) => null;
}

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
  final trail = TrailManifest(locations: const [
    TrailLocation(
      locationId: 'wallys-1',
      buildingId: 'wallys-1',
      title: '1 Wally\'s Walk',
      photos: ['assets/photos/_placeholder.jpg'],
      arSceneId: 'entrance',
      stops: [
        OpenDayStop(
            stopId: 'wallys-1-g03', title: 'Theatre G03', arSceneId: 'theatre-g03'),
      ],
    ),
  ]);

  const registry = BuildingsRegistry(buildings: [
    BuildingEntry(
      code: 'wallys-1',
      name: '1 Wally\'s Walk',
      campusX: 0,
      campusY: 0,
      entranceLatitude: -33.7747,
      entranceLongitude: 151.1142,
    ),
  ]);

  // Inferred return type is List<Override> — never named explicitly.
  baseOverrides({String? scheduleUrl}) => [
        trailManifestProvider.overrideWith((ref) async => trail),
        buildingsRegistryProvider.overrideWith((ref) async => registry),
        locationContentProvider.overrideWith((ref, id) => LocationContent(
              locationId: id,
              title: '1 Wally\'s Walk',
              heroImageAsset: 'assets/images/placeholder_hero.png',
              shortDescription: 'One. Two. Three.',
              buildingId: 'wallys-1',
              fullScheduleUrl: scheduleUrl,
            )),
        scheduleProvider.overrideWith((ref) => _NoSchedule()),
        visitedStateProvider.overrideWith((ref, id) => Stream.value(
            const VisitedState(visited: false, rewardEarned: false))),
        myDayApiProvider.overrideWith((ref) => FakeMyDayApi()),
      ];

  testWidgets('renders gallery, 3-sentence read, both buttons and stops',
      (tester) async {
    await tester.pumpWidget(
        ProviderScope(overrides: baseOverrides(), child: _app()));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoGallery), findsOneWidget);
    expect(find.text('One. Two. Three.'), findsOneWidget);
    expect(find.text('View on Campus Map'), findsOneWidget);
    expect(find.text('View AR map'), findsOneWidget);
    expect(find.byType(OpenDayStopsTable), findsOneWidget);
    expect(find.text('Theatre G03'), findsOneWidget);
    expect(find.text('Full schedule'), findsNothing); // fullScheduleUrl null
  });

  testWidgets('hides AR button when no scene anywhere', (tester) async {
    final t = TrailManifest(locations: const [
      TrailLocation(locationId: 'wallys-1', buildingId: 'wallys-1', title: 'x'),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        trailManifestProvider.overrideWith((ref) async => t),
        ...baseOverrides().skip(1),
      ],
      child: _app(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('View AR map'), findsNothing);
  });

  testWidgets('Campus Map button disabled when building not in registry',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        trailManifestProvider.overrideWith((ref) async => trail),
        buildingsRegistryProvider.overrideWith((ref) async => registry),
        locationContentProvider.overrideWith((ref, id) => LocationContent(
              locationId: id,
              title: 'x',
              heroImageAsset: 'assets/images/placeholder_hero.png',
              shortDescription: 'One. Two. Three.',
              buildingId: 'not-in-registry', // absent from registry
            )),
        scheduleProvider.overrideWith((ref) => _NoSchedule()),
        visitedStateProvider.overrideWith((ref, id) => Stream.value(
            const VisitedState(visited: false, rewardEarned: false))),
        myDayApiProvider.overrideWith((ref) => FakeMyDayApi()),
      ],
      child: _app(),
    ));
    await tester.pumpAndSettle();
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'View on Campus Map'),
    );
    expect(button.onPressed, isNull); // disabled — never opens an empty map
  });

  testWidgets('Full schedule link shows when fullScheduleUrl is set',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: baseOverrides(scheduleUrl: 'https://mq.edu.au/openday'),
      child: _app(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Full schedule'), findsOneWidget);
  });
}
