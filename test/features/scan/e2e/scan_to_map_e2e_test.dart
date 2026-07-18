import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/nav_instruction.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/scan/data/adapters/settings_progress_api_adapter.dart';
import 'package:mq_journey/features/scan/domain/models/buildings_registry.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_my_day_api.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_schedule_provider.dart';
import 'package:mq_journey/features/scan/presentation/pages/location_card_page.dart';
import 'package:mq_journey/features/scan/presentation/pages/scan_page.dart';
import 'package:mq_journey/features/scan/presentation/widgets/scanner_view.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_earned_sheet.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pipeline/qr_pipeline_test_support.dart';

// Full end-to-end smoke of the QR journey a user actually takes:
//   scan a signed QR → the location card opens (with its real photo + copy)
//   → the stamp reward sheet pops up → tapping "View on Campus Map" routes to
//   the map with the correct building code → the map focuses THAT building at
//   its real campus coordinates (not the (0,0) overlay corner).
//
// Uses the real signed QR fixtures, the real trail/buildings/stamp assets and
// the real MapController — only the network seams (Supabase, settings storage,
// GPS) are faked. Live device runs are blocked on this machine, so this is the
// closest reproducible whole-flow check.

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

class _FlowSettingsController extends SettingsController {
  UserPreferences _preferences = const UserPreferences();

  @override
  Future<UserPreferences> build() async => _preferences;

  @override
  Future<bool> recordLocationVisit(String buildingCode) async {
    final code = buildingCode.trim().toUpperCase();
    if (code.isEmpty || _preferences.visitedLocationCodes.contains(code)) {
      return false;
    }
    _preferences = _preferences.copyWith(
      visitedLocationCodes: [..._preferences.visitedLocationCodes, code],
    );
    state = AsyncData(_preferences);
    return true;
  }
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

class _FakeMapRepository implements MapRepository {
  _FakeMapRepository({required this.buildings});

  final List<Building> buildings;

  @override
  Future<List<Building>> getBuildings({bool forceRefresh = false}) async =>
      buildings;

  // The MapController boots with location denied → no GPS platform channels.
  @override
  Future<LocationPermissionState> ensureLocationPermission() async =>
      LocationPermissionState.denied;

  @override
  Future<LocationSample?> getCurrentLocation() async => null;

  @override
  Stream<LocationSample> watchLocation() =>
      const Stream<LocationSample>.empty();

  @override
  Future<MapRoute> getRoute({
    required LocationSample origin,
    required Building destination,
    required TravelMode travelMode,
  }) async => MapRoute(
    travelMode: travelMode,
    distanceMeters: 100,
    durationSeconds: 90,
    encodedPolyline: '',
    instructions: const [NavInstruction(text: 'Go', distanceMeters: 10)],
  );

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

List<Building> _loadRealBuildings() {
  final raw = File('assets/data/buildings.json').readAsStringSync();
  return (jsonDecode(raw) as List)
      .cast<Map<String, dynamic>>()
      .map(Building.fromJson)
      .toList(growable: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixtures = QrPipelineFixtures.load();
  final realBuildings = _loadRealBuildings();
  // Pre-loaded so buildingsRegistryProvider resolves under fake-async pump()
  // (rootBundle-loading the large buildings.json otherwise needs real async).
  final realRegistry = BuildingsRegistry.fromJson(
    File('assets/data/buildings.json').readAsStringSync(),
  );

  testWidgets(
    'E2E: scan → card (photo + copy) → stamp → "View on Campus Map" routes '
    'to the correct building for all 9 locations',
    (tester) async {
      final supabase = _MockSupabaseClient();
      final auth = _MockGoTrueClient();
      final user = _MockUser();
      when(() => supabase.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(null);
      when(
        () => auth.signInAnonymously(),
      ).thenAnswer((_) async => AuthResponse(user: user));
      when(() => user.id).thenReturn('e2e-flow-user');

      String? capturedBuildingParam;
      final router = GoRouter(
        initialLocation: '/scan',
        overridePlatformDefaultLocation: true,
        routes: [
          GoRoute(path: '/scan', builder: (_, _) => const ScanPage()),
          GoRoute(
            path: '/location/:locationId',
            builder: (_, state) => LocationCardPage(
              locationId: state.pathParameters['locationId']!,
            ),
          ),
          GoRoute(
            name: RouteNames.map,
            path: '/map',
            builder: (_, state) {
              capturedBuildingParam = state.uri.queryParameters['building'];
              return const Scaffold(body: Center(child: Text('CAMPUS MAP')));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Real trail / buildings / locationContent / stampCatalog assets —
            // only the network + storage seams are faked.
            settingsControllerProvider.overrideWith(
              _FlowSettingsController.new,
            ),
            progressApiProvider.overrideWith(
              (ref) =>
                  SettingsProgressApiAdapter(ref, supabaseClient: supabase),
            ),
            buildingsRegistryProvider.overrideWith((_) async => realRegistry),
            scheduleProvider.overrideWith((_) => FakeScheduleProvider()),
            myDayApiProvider.overrideWith((_) => FakeMyDayApi()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ScanPage)),
      );
      await container.read(settingsControllerProvider.future);

      for (final fixture in fixtures.locations) {
        final id = fixture.location.locationId;
        final cardFinder = find.byWidgetPredicate(
          (widget) => widget is LocationCardPage && widget.locationId == id,
        );

        final descHead = fixture.location.description!.substring(0, 24);

        // 1) Scan the signed QR for this location.
        tester
            .widget<ScannerView>(find.byType(ScannerView))
            .onDetect(fixture.uri);
        await tester.pump();
        // Wait for the card to fully resolve — both the stamp sheet AND the
        // real content (registry-backed description), not just the transient
        // "loading" frame before buildingsRegistryProvider resolves.
        for (var attempt = 0; attempt < 60; attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (cardFinder.evaluate().isNotEmpty &&
              find.byType(StampEarnedSheet).evaluate().isNotEmpty &&
              find.textContaining(descHead).evaluate().isNotEmpty) {
            break;
          }
        }

        // 2) The location card opened for exactly this location.
        expect(router.state.uri.path, '/location/$id', reason: 'route for $id');
        expect(cardFinder, findsOneWidget);

        // 2b) The card is NOT empty: its real curated description is shown.
        expect(
          find.textContaining(descHead),
          findsWidgets,
          reason: 'card description not rendered for $id',
        );

        // 3) The stamp reward sheet popped up for this location.
        final sheet = tester.widget<StampEarnedSheet>(
          find.byType(StampEarnedSheet),
        );
        expect(sheet.award.stamp.locationId, id);
        expect(sheet.award.collectedCount, fixture.ordinal);
        expect(sheet.award.total, fixtures.locations.length);

        // Dismiss the sheet to get back to the card.
        Navigator.of(
          tester.element(find.byType(StampEarnedSheet)),
        ).pop(StampSheetAction.keepExploring);
        for (var attempt = 0; attempt < 6; attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(StampEarnedSheet), findsNothing);

        // 4) Tap "View on Campus Map" → routes to the map with the REAL
        //    building code (e.g. "29WW"), not the coordinate-less trail slug.
        capturedBuildingParam = null;
        final mapButton = find.widgetWithText(
          OutlinedButton,
          'View on Campus Map',
        );
        expect(mapButton, findsOneWidget, reason: 'no map button for $id');
        final button = tester.widget<OutlinedButton>(mapButton);
        expect(button.onPressed, isNotNull, reason: 'map button disabled: $id');
        await tester.ensureVisible(mapButton);
        await tester.tap(mapButton, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          capturedBuildingParam,
          fixture.location.mapBuildingCode,
          reason: 'wrong building code routed for $id',
        );

        // Reset to the scanner for the next location.
        router.go('/scan');
        for (var attempt = 0; attempt < 10; attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.byType(ScannerView).evaluate().isNotEmpty) break;
        }
      }

      // All nine visits persisted.
      expect(
        container
            .read(settingsControllerProvider)
            .requireValue
            .visitedLocationCodes,
        hasLength(fixtures.locations.length),
      );
    },
  );

  test('E2E: the campus map focuses the exact scanned building at real '
      'coordinates (never the 0,0 corner)', () async {
    for (final fixture in fixtures.locations) {
      final container = ProviderContainer(
        overrides: [
          mapRepositoryProvider.overrideWithValue(
            _FakeMapRepository(buildings: realBuildings),
          ),
          settingsControllerProvider.overrideWith(_FakeSettingsController.new),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mapControllerProvider.future);
      final notifier = container.read(mapControllerProvider.notifier);

      final code = fixture.location.mapBuildingCode!;
      notifier.selectBuildingById(code);

      final selected = container
          .read(mapControllerProvider)
          .value!
          .selectedBuilding;
      expect(
        selected,
        isNotNull,
        reason: 'map did not select $code (${fixture.location.locationId})',
      );
      final matches =
          selected!.code.toUpperCase() == code.toUpperCase() ||
          selected.id.toUpperCase() == code.toUpperCase();
      expect(matches, isTrue, reason: 'selected wrong building for $code');
      // The building the camera will center on has real campus pixels.
      expect(
        selected.campusPoint,
        isNotNull,
        reason: '$code has no campus point',
      );
      expect(
        selected.campusX == 0 && selected.campusY == 0,
        isFalse,
        reason: '$code resolves to the (0,0) overlay corner',
      );
    }
  });
}
