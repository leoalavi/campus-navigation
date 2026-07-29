import 'dart:async';

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

/// Open/close behaviour of the Campus Map search sheet.
///
/// The sheet used to render an empty `ListView` whenever the registry had not
/// finished decoding — `state.value` was null, so `searchResults` fell back to
/// `const []` and the user got a blank panel with no explanation. It also had
/// no keyboard-inset handling despite autofocusing its field.

class _FakeSettingsController extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

class _FakeMapRepository implements MapRepository {
  _FakeMapRepository(this.buildings, {this.gate, this.throwOnLoad = false});

  final List<Building> buildings;

  /// When supplied, `getBuildings` waits on this before completing, which
  /// holds the controller in its loading state for as long as the test wants.
  final Future<void>? gate;
  final bool throwOnLoad;

  @override
  Future<List<Building>> getBuildings({bool forceRefresh = false}) async {
    if (gate != null) await gate;
    if (throwOnLoad) throw StateError('registry unavailable');
    return buildings;
  }

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

List<Building> _buildings() => [
  Building.fromJson({
    'id': 'wallys-11',
    'code': '11WW',
    'name': "11 Wally's Walk",
    'location': {'lat': -33.775, 'lng': 151.113},
    'category': 'academic',
  }),
  Building.fromJson({
    'id': 'library',
    'code': 'LIB',
    'name': 'Waranara Library',
    'location': {'lat': -33.774, 'lng': 151.112},
    'category': 'library',
  }),
];

/// A host page with a button that opens the sheet, so the real
/// `showModalBottomSheet` lifecycle (including repeat opens) is exercised.
Widget _host(MapRepository repo) {
  return ProviderScope(
    overrides: [
      mapRepositoryProvider.overrideWithValue(repo),
      settingsControllerProvider.overrideWith(_FakeSettingsController.new),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet<Building>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const BuildingSearchSheet(),
            ),
            child: const Text('open-search'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open-search'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('first tap opens the sheet and lists buildings', (tester) async {
    await tester.pumpWidget(_host(_FakeMapRepository(_buildings())));
    await tester.pumpAndSettle();

    await _openSheet(tester);

    expect(find.byType(BuildingSearchSheet), findsOneWidget);
    expect(find.text("11 Wally's Walk"), findsOneWidget);
    expect(find.text('Waranara Library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a loading state while the registry is still decoding', (
    tester,
  ) async {
    // Regression: this rendered a blank ListView (itemCount 0) with no
    // spinner, which read as "search is broken" on a cold first open.
    final gate = Completer<void>();
    await tester.pumpWidget(
      _host(_FakeMapRepository(_buildings(), gate: gate.future)),
    );
    await tester.pump();

    await _openSheet(tester);

    expect(
      find.byKey(const Key('building-search-loading')),
      findsOneWidget,
      reason: 'a pending registry must show progress, not an empty list',
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('building-search-loading')), findsNothing);
    expect(find.text('Waranara Library'), findsOneWidget);
  });

  testWidgets('shows an error state when the registry fails', (tester) async {
    await tester.pumpWidget(
      _host(_FakeMapRepository(const [], throwOnLoad: true)),
    );
    await tester.pumpAndSettle();

    await _openSheet(tester);

    expect(find.byKey(const Key('building-search-error')), findsOneWidget);
    expect(find.byKey(const Key('building-search-loading')), findsNothing);
  });

  testWidgets('typing filters the list', (tester) async {
    await tester.pumpWidget(_host(_FakeMapRepository(_buildings())));
    await tester.pumpAndSettle();
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'Waranara');
    await tester.pumpAndSettle();

    expect(find.text('Waranara Library'), findsOneWidget);
    expect(find.text("11 Wally's Walk"), findsNothing);
  });

  testWidgets('Back closes the sheet, and it reopens cleanly', (tester) async {
    await tester.pumpWidget(_host(_FakeMapRepository(_buildings())));
    await tester.pumpAndSettle();

    for (var cycle = 0; cycle < 3; cycle++) {
      await _openSheet(tester);
      expect(
        find.byType(BuildingSearchSheet),
        findsOneWidget,
        reason: 'cycle $cycle should open',
      );

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(
        find.byType(BuildingSearchSheet),
        findsNothing,
        reason: 'cycle $cycle should close',
      );
      expect(tester.takeException(), isNull, reason: 'cycle $cycle');
    }
  });

  testWidgets('the sheet reserves space for the keyboard', (tester) async {
    // showModalBottomSheet applies no viewInsets padding of its own, so the
    // sheet must do it: without this the autofocused keyboard covers the
    // bottom of the results list.
    const keyboard = 300.0;
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(_host(_FakeMapRepository(_buildings())));
    await tester.pumpAndSettle();
    await _openSheet(tester);

    final bottoms = find
        .descendant(
          of: find.byType(BuildingSearchSheet),
          matching: find.byType(Padding),
        )
        .evaluate()
        .map((e) => (e.widget as Padding).padding.resolve(null).bottom);

    expect(
      bottoms,
      contains(keyboard),
      reason:
          'the sheet must offset itself by the keyboard inset — '
          'showModalBottomSheet does not do it for us',
    );
  });

  testWidgets('selecting a result returns the building and closes', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_FakeMapRepository(_buildings())));
    await tester.pumpAndSettle();
    await _openSheet(tester);

    await tester.tap(find.text('Waranara Library'));
    await tester.pumpAndSettle();

    expect(find.byType(BuildingSearchSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
