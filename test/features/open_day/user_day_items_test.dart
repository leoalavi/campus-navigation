import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_progress.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/providers/trail_providers.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._prefs);
  final UserPreferences _prefs;

  @override
  Future<UserPreferences> build() async => _prefs;
}

final _data = OpenDayData(
  openDayDate: DateTime(2026, 8, 15),
  lastUpdated: DateTime(2026, 8, 1),
  studyAreas: const [],
  bachelors: const [],
  events: const [],
  suggestedStops: const [
    OpenDaySuggestedStop(
      id: 'stop-library',
      title: 'Waranara Library',
      description: 'Study spaces.',
    ),
  ],
);

const _trail = TrailManifest(
  locations: [
    TrailLocation(
      locationId: 'wallys-29',
      buildingId: 'wallys-29',
      mapBuildingCode: '29WW',
      title: "29 Wally's Walk",
      description: 'Faculty of Arts building.',
    ),
  ],
);

ProviderContainer _containerWith(List<String> savedStopIds) {
  final container = ProviderContainer(
    overrides: [
      openDayDataProvider.overrideWith((ref) async => _data),
      trailManifestProvider.overrideWith((ref) async => _trail),
      settingsControllerProvider.overrideWith(
        () => _FakeSettingsController(
          UserPreferences(savedStopIds: savedStopIds),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _warmUp(ProviderContainer c) async {
  await c.read(openDayDataProvider.future);
  await c.read(trailManifestProvider.future);
  await c.read(settingsControllerProvider.future);
}

void main() {
  group('userDayItemsProvider resolves saved scanned venues', () {
    test('a saved trail venue id surfaces as a Your Day stop', () async {
      final c = _containerWith(['wallys-29']);
      await _warmUp(c);

      final items = c.read(userDayItemsProvider);
      final stops = items.whereType<UserDayStop>().toList();
      expect(stops, hasLength(1));
      expect(stops.single.stop.title, "29 Wally's Walk");
      // Resolved buildingCode comes from the trail's mapBuildingCode so the
      // Your Day row's "view on map" lands on the real building.
      expect(stops.single.stop.buildingCode, '29WW');
    });

    test('still resolves genuine suggested stops', () async {
      final c = _containerWith(['stop-library']);
      await _warmUp(c);

      final stops = c.read(userDayItemsProvider).whereType<UserDayStop>();
      expect(stops.single.stop.title, 'Waranara Library');
    });

    test('empty saved list yields no items', () async {
      final c = _containerWith(const []);
      await _warmUp(c);
      expect(c.read(userDayItemsProvider), isEmpty);
    });

    test(
      'unknown ids (neither stop nor venue) are dropped, not crashed',
      () async {
        final c = _containerWith(['ghost-id', 'wallys-29']);
        await _warmUp(c);
        final stops = c.read(userDayItemsProvider).whereType<UserDayStop>();
        expect(stops, hasLength(1));
        expect(stops.single.stop.title, "29 Wally's Walk");
      },
    );
  });
}
