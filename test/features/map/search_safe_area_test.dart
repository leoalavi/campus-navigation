import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/data/datasources/building_registry_source.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/data/repositories/map_repository_impl.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/presentation/widgets/building_search_sheet.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

/// The search surface is a full-screen route, so it owns its own safe area.
///
/// It used to be a `showModalBottomSheet(useSafeArea: true)`, which supplied
/// the top inset for free. Promoting it to a route (so the map stops blurring
/// underneath) dropped that with it, and the search field and its Back control
/// drifted under the status bar / notch / Dynamic Island.

class _FakeSettings extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

class _FakeRepo implements MapRepository {
  @override
  Future<List<Building>> getBuildings({bool forceRefresh = false}) async => [
    _a,
    _b,
  ];
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

/// Hosts the search surface under a chosen device inset.
Widget _host({
  required EdgeInsets viewPadding,
  EdgeInsets viewInsets = EdgeInsets.zero,
  Locale locale = const Locale('en'),
}) => ProviderScope(
  overrides: [
    mapRepositoryProvider.overrideWithValue(_FakeRepo()),
    buildingRegistryProvider.overrideWith((ref) async => [_a, _b]),
    settingsControllerProvider.overrideWith(_FakeSettings.new),
  ],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        viewPadding: viewPadding,
        padding: viewPadding,
        viewInsets: viewInsets,
      ),
      child: const BuildingSearchSheet(),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Topmost pixel of the first interactive control in the header.
double _headerTop(WidgetTester tester) =>
    tester.getRect(find.byType(TextField)).top;

void main() {
  testWidgets('1. no-notch device: header starts at the top edge', (
    tester,
  ) async {
    await tester.pumpWidget(_host(viewPadding: EdgeInsets.zero));
    await _settle(tester);
    expect(_headerTop(tester), greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });

  for (final (inset, name) in const [
    (44.0, 'notch'),
    (59.0, 'Dynamic Island'),
    (24.0, 'Android cutout'),
  ]) {
    testWidgets('2-3. $name: the search field clears the unsafe area', (
      tester,
    ) async {
      await tester.pumpWidget(_host(viewPadding: EdgeInsets.only(top: inset)));
      await _settle(tester);

      expect(
        _headerTop(tester),
        greaterThanOrEqualTo(inset),
        reason: 'the first interactive control must never sit under the $name',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('4-5. the field stays visible and reachable under a notch', (
    tester,
  ) async {
    await tester.pumpWidget(_host(viewPadding: const EdgeInsets.only(top: 59)));
    await _settle(tester);

    final field = tester.getRect(find.byType(TextField));
    expect(field.height, greaterThan(20));
    expect(field.width, greaterThan(100));
    // Tappable rather than merely present.
    await tester.tap(find.byType(TextField));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('6. the keyboard does not push the header into the notch', (
    tester,
  ) async {
    // With the IME up, `padding.top` can be reported as zero; reading
    // `viewPadding` is what keeps the header below the physical intrusion.
    await tester.pumpWidget(
      _host(
        viewPadding: const EdgeInsets.only(top: 59),
        viewInsets: const EdgeInsets.only(bottom: 336),
      ),
    );
    await _settle(tester);

    expect(_headerTop(tester), greaterThanOrEqualTo(59));
    expect(tester.takeException(), isNull);
  });

  testWidgets('7. narrow phone width does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(viewPadding: const EdgeInsets.only(top: 44)));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('8. fa/RTL keeps the same safe-area behaviour', (tester) async {
    await tester.pumpWidget(
      _host(
        viewPadding: const EdgeInsets.only(top: 59),
        locale: const Locale('fa'),
      ),
    );
    await _settle(tester);

    expect(_headerTop(tester), greaterThanOrEqualTo(59));
    expect(
      Directionality.of(tester.element(find.byType(TextField))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}
