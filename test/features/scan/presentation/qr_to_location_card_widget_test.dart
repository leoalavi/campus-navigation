import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/data/adapters/settings_progress_api_adapter.dart';
import 'package:mq_journey/features/scan/domain/contracts/location_content.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_my_day_api.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_schedule_provider.dart';
import 'package:mq_journey/features/scan/presentation/pages/location_card_page.dart';
import 'package:mq_journey/features/scan/presentation/pages/scan_page.dart';
import 'package:mq_journey/features/scan/presentation/pages/stamps_passport_page.dart';
import 'package:mq_journey/features/scan/presentation/widgets/scanner_view.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_earned_sheet.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pipeline/qr_pipeline_test_support.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

class _PipelineSettingsController extends SettingsController {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixtures = QrPipelineFixtures.load();

  testWidgets('all nine decoded QRs open matching cards and stamps', (
    tester,
  ) async {
    final supabase = _MockSupabaseClient();
    final auth = _MockGoTrueClient();
    final user = _MockUser();
    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => auth.signInAnonymously(),
    ).thenAnswer((_) async => AuthResponse(user: user));
    when(() => user.id).thenReturn('isolated-pipeline-user');

    final router = GoRouter(
      initialLocation: '/scan',
      overridePlatformDefaultLocation: true,
      routes: [
        GoRoute(path: '/scan', builder: (_, _) => const ScanPage()),
        GoRoute(
          path: '/location/:locationId',
          builder: (_, state) =>
              LocationCardPage(locationId: state.pathParameters['locationId']!),
        ),
        GoRoute(path: '/stamps', builder: (_, _) => const StampsPassportPage()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(
            _PipelineSettingsController.new,
          ),
          progressApiProvider.overrideWith(
            (ref) => SettingsProgressApiAdapter(ref, supabaseClient: supabase),
          ),
          locationContentProvider.overrideWith((_, locationId) {
            final fixture = fixtures.locations.singleWhere(
              (candidate) => candidate.location.locationId == locationId,
            );
            return LocationContent(
              locationId: locationId,
              title: fixture.location.title,
              heroImageAsset: 'assets/images/placeholder_hero.png',
              shortDescription: 'A featured Open Day location.',
              buildingId: fixture.location.buildingId,
            );
          }),
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
      final cardFinder = find.byWidgetPredicate(
        (widget) =>
            widget is LocationCardPage &&
            widget.locationId == fixture.location.locationId,
      );
      tester
          .widget<ScannerView>(find.byType(ScannerView))
          .onDetect(fixture.uri);
      await tester.pump();
      for (var attempt = 0; attempt < 30; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (cardFinder.evaluate().isNotEmpty &&
            find.byType(StampEarnedSheet).evaluate().isNotEmpty) {
          break;
        }
      }

      final card = tester.widget<LocationCardPage>(cardFinder);
      final sheet = tester.widget<StampEarnedSheet>(
        find.byType(StampEarnedSheet),
      );
      expect(router.state.uri.path, '/location/${fixture.location.locationId}');
      expect(card.locationId, fixture.location.locationId);
      expect(sheet.award.stamp.locationId, fixture.location.locationId);
      expect(sheet.award.stamp.title, fixture.stamp.title);
      expect(sheet.award.stamp.mapRef, fixture.stamp.mapRef);
      expect(sheet.award.collectedCount, fixture.ordinal);
      expect(sheet.award.total, fixtures.locations.length);
      expect(sheet.playEffects, isFalse);

      Navigator.of(
        tester.element(find.byType(StampEarnedSheet)),
      ).pop(StampSheetAction.keepExploring);
      for (var attempt = 0; attempt < 5; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(StampEarnedSheet), findsNothing);
      expect(find.text(fixture.location.title), findsWidgets);

      router.go('/scan');
      for (var attempt = 0; attempt < 10; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(ScannerView).evaluate().isNotEmpty) break;
      }
    }

    expect(
      container
          .read(settingsControllerProvider)
          .requireValue
          .visitedLocationCodes,
      hasLength(fixtures.locations.length),
    );
  });
}
