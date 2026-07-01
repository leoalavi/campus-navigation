import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/presentation/pages/stamps_passport_page.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/settings/data/repositories/settings_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

const _catalog = [
  StampCatalogEntry(
    locationId: 'wallys-1',
    title: "1 Wally's Walk",
    mapRef: 'K27',
    stampAsset: 'assets/stamps/wallys-1.png',
  ),
  StampCatalogEntry(
    locationId: 'wallys-25',
    title: "25 Wally's Walk",
    mapRef: 'N12',
    stampAsset: 'assets/stamps/wallys-25.png',
  ),
];

void main() {
  setUpAll(() {
    registerFallbackValue(const UserPreferences());
  });

  Widget buildApp(MockSettingsRepository mockRepo) {
    final router = GoRouter(
      initialLocation: '/stamps',
      routes: [
        GoRoute(path: '/stamps', builder: (_, _) => const StampsPassportPage()),
        GoRoute(
          path: '/location/:locationId',
          builder: (_, s) => Scaffold(
            body: Text('location-${s.pathParameters['locationId']}'),
          ),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(mockRepo),
        stampCatalogProvider.overrideWith((ref) async => _catalog),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('shows collected and locked cells with correct progress ring', (
    tester,
  ) async {
    final mockRepo = MockSettingsRepository();
    when(() => mockRepo.loadPreferences()).thenAnswer(
      (_) async => const UserPreferences(visitedLocationCodes: ['WALLYS-1']),
    );

    await tester.pumpWidget(buildApp(mockRepo));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text("1 Wally's Walk"), findsOneWidget);
    expect(find.text("25 Wally's Walk"), findsOneWidget);
  });

  testWidgets('tapping a collected stamp opens its location card', (
    tester,
  ) async {
    final mockRepo = MockSettingsRepository();
    when(() => mockRepo.loadPreferences()).thenAnswer(
      (_) async => const UserPreferences(visitedLocationCodes: ['WALLYS-1']),
    );

    await tester.pumpWidget(buildApp(mockRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text("1 Wally's Walk"));
    await tester.pumpAndSettle();

    expect(find.text('location-wallys-1'), findsOneWidget);
  });
}
