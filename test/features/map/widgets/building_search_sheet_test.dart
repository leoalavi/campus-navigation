import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/presentation/widgets/building_search_sheet.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class _FakeSettingsController extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

class _FakeMapRepository implements MapRepository {
  _FakeMapRepository({required this.buildings});

  final List<Building> buildings;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<LocationPermissionState> ensureLocationPermission() async =>
      LocationPermissionState.granted;

  @override
  Future<List<Building>> getBuildings({bool forceRefresh = false}) async =>
      buildings;

  @override
  Future<LocationSample?> getCurrentLocation() async => null;

  @override
  Future<MapRoute> getRoute({
    required LocationSample origin,
    required Building destination,
    required TravelMode travelMode,
  }) async => MapRoute(
    travelMode: travelMode,
    distanceMeters: 100,
    durationSeconds: 60,
    encodedPolyline: '',
    instructions: const [],
  );

  @override
  Stream<LocationSample> watchLocation() => const Stream.empty();
}

void main() {
  final library = Building.fromJson({
    'id': 'LIB',
    'code': 'LIB',
    'name': 'Waranara Library',
    'location': {'lat': -33.7756, 'lng': 151.1131},
    'category': 'academic',
  });
  final commons = Building.fromJson({
    'id': '1CC',
    'code': '1CC',
    'name': 'Campus Commons',
    'location': {'lat': -33.773, 'lng': 151.112},
    'category': 'academic',
  });

  Widget host(_FakeMapRepository repo) {
    return ProviderScope(
      overrides: [
        mapRepositoryProvider.overrideWithValue(repo),
        settingsControllerProvider.overrideWith(
          () => _FakeSettingsController(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<Building>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const BuildingSearchSheet(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders a single search field and pops the tapped building', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(_FakeMapRepository(buildings: [library, commons])),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Exactly one search input — no duplicate/leftover search bar.
    expect(find.byType(TextField), findsOneWidget);

    // Results are listed; tapping one closes the sheet with that building.
    expect(find.text('Waranara Library'), findsOneWidget);
    await tester.tap(find.text('Waranara Library'));
    await tester.pumpAndSettle();

    expect(find.byType(BuildingSearchSheet), findsNothing);
  });

  testWidgets('typing filters results and clear resets the query', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(_FakeMapRepository(buildings: [library, commons])),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'library');
    await tester.pumpAndSettle();
    expect(find.text('Waranara Library'), findsOneWidget);

    // The clear (suffix) button appears once there's a query and resets it.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}
