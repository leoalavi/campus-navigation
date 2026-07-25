import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/map/data/datasources/building_registry_source.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/open_day/presentation/pages/your_day_page.dart';
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

const _building = Building(
  id: 'wallys-29',
  code: '29WW',
  name: "29 Wally's Walk",
);

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
      description: 'Study spaces at the heart of campus.',
      buildingCode: '29WW',
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

Widget _app() {
  final router = GoRouter(
    initialLocation: '/your-day',
    routes: [
      GoRoute(path: '/your-day', builder: (_, _) => const YourDayPage()),
      GoRoute(
        path: '/map',
        name: 'map',
        builder: (_, _) => const Scaffold(body: Text('map-page')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      openDayDataProvider.overrideWith((ref) async => _data),
      trailManifestProvider.overrideWith((ref) async => _trail),
      buildingRegistryProvider.overrideWith((ref) async => const [_building]),
      settingsControllerProvider.overrideWith(
        () => _FakeSettingsController(
          const UserPreferences(savedStopIds: ['stop-library']),
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

void main() {
  testWidgets('the map and remove buttons are comfortably tappable on mobile', (
    tester,
  ) async {
    // A typical phone width — the row must still give both trailing controls a
    // full tap target rather than shrinking them to fit.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Waranara Library'), findsOneWidget);

    for (final icon in const [Icons.map_outlined, Icons.close_rounded]) {
      final size = tester.getSize(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(InkWell)),
      );
      expect(
        size.width,
        greaterThanOrEqualTo(MqSpacing.minTapTarget),
        reason: '$icon is too narrow to hit reliably on a phone',
      );
      expect(
        size.height,
        greaterThanOrEqualTo(MqSpacing.minTapTarget),
        reason: '$icon is too short to hit reliably on a phone',
      );
    }
  });

  testWidgets('enlarging the buttons does not wrap the stop title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // The title ellipsises inside an Expanded, so bigger buttons must eat
    // into the text's width rather than push the row onto a second line.
    final title = tester.widget<Text>(find.text('Waranara Library'));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}
