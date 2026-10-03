import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_navigation/app/l10n/generated/app_localizations.dart';
import 'package:campus_navigation/app/router/shell_chrome_provider.dart';
import 'package:campus_navigation/features/map/data/repositories/map_repository_impl.dart';
import 'package:campus_navigation/features/map/domain/entities/building.dart';
import 'package:campus_navigation/features/map/domain/entities/map_renderer_type.dart';
import 'package:campus_navigation/features/map/domain/entities/route_leg.dart';
import 'package:campus_navigation/features/map/data/datasources/location_source.dart';
import 'package:campus_navigation/features/map/presentation/widgets/overlay_picker_sheet.dart';
import 'package:campus_navigation/features/settings/presentation/controllers/settings_controller.dart';
import 'package:campus_navigation/shared/models/user_preferences.dart';

class _FakeSettingsController extends SettingsController {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

class _FakeMapRepository implements MapRepository {
  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<LocationPermissionState> ensureLocationPermission() async =>
      LocationPermissionState.granted;

  @override
  Future<List<Building>> getBuildings({bool forceRefresh = false}) async =>
      const [];

  @override
  Future<LocationSample?> getCurrentLocation() async => null;

  @override
  Future<MapRoute> getRoute({
    required MapRendererType renderer,
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

  @override
  Stream<LocationSample> watchLocation() => const Stream.empty();
}

/// Regression: the Layers sheet overflowed ("BOTTOM OVERFLOWED BY 1.6
/// PIXELS") because it was a fixed Column inside a 9/16-height modal whose
/// SafeArea also padded for the floating nav bar. It must now fit — or
/// scroll — on small phones with large text.
void main() {
  for (final (label, size, scale) in const [
    ('iPhone SE', Size(320, 568), 1.0),
    ('iPhone SE, large text', Size(320, 568), 1.6),
    ('standard phone', Size(390, 844), 1.0),
    ('tablet', Size(820, 1180), 1.3),
  ]) {
    testWidgets('Layers sheet has no overflow on $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapRepositoryProvider.overrideWithValue(_FakeMapRepository()),
            settingsControllerProvider.overrideWith(
              _FakeSettingsController.new,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => ref
                        .read(shellChromeProvider.notifier)
                        .guard(
                          showModalBottomSheet<void>(
                            context: context,
                            useRootNavigator: true,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => const OverlayPickerSheet(),
                          ),
                        ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(OverlayPickerSheet), findsOneWidget);
      // Every toggle is reachable (scrolling if needed) — none clipped away.
      final switches = find.byType(Switch, skipOffstage: false);
      expect(switches, findsNWidgets(4));
      await tester.ensureVisible(switches.last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bottom navigation is hidden while the Layers sheet is open', (
    tester,
  ) async {
    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapRepositoryProvider.overrideWithValue(_FakeMapRepository()),
          settingsControllerProvider.overrideWith(_FakeSettingsController.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return Scaffold(
                body: TextButton(
                  onPressed: () => ref
                      .read(shellChromeProvider.notifier)
                      .guard(
                        showModalBottomSheet<void>(
                          context: context,
                          useRootNavigator: true,
                          isScrollControlled: true,
                          builder: (_) => const OverlayPickerSheet(),
                        ),
                      ),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(capturedRef.read(bottomNavVisibleProvider), isTrue);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(capturedRef.read(bottomNavVisibleProvider), isFalse);

    Navigator.of(tester.element(find.byType(OverlayPickerSheet))).pop();
    await tester.pumpAndSettle();
    expect(capturedRef.read(bottomNavVisibleProvider), isTrue);
  });
}
