import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/map/data/services/offline_maps_service.dart';
import 'package:mq_journey/features/notifications/data/datasources/fcm_service.dart';
import 'package:mq_journey/features/notifications/domain/entities/app_notification.dart';
import 'package:mq_journey/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/settings/data/repositories/settings_repository.dart';
import 'package:mq_journey/features/settings/presentation/pages/settings_page.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockOfflineMapsService extends Mock implements OfflineMapsService {}

class _FakeNotificationsController extends NotificationsController {
  @override
  Future<NotificationsState> build() async => const NotificationsState(
    permissionStatus: NotificationPermissionStatus.granted,
    preferences: [],
  );

  @override
  Future<void> updatePreference(NotificationType type, bool enabled) async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(const UserPreferences());
  });

  testWidgets('My Stamps tile navigates to /stamps', (tester) async {
    final mockSettingsRepository = MockSettingsRepository();
    final mockOfflineMapsService = MockOfflineMapsService();
    when(
      () => mockSettingsRepository.loadPreferences(),
    ).thenAnswer((_) async => const UserPreferences());
    when(() => mockSettingsRepository.savePreferences(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments[0] as UserPreferences,
    );
    when(() => mockOfflineMapsService.isFmtcBackendReady).thenReturn(false);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          name: RouteNames.settings,
          builder: (_, _) => const SettingsPage(),
        ),
        GoRoute(
          path: '/stamps',
          name: RouteNames.stamps,
          builder: (_, _) => const Scaffold(body: Text('stamps-page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
          offlineMapsServiceProvider.overrideWithValue(mockOfflineMapsService),
          notificationsControllerProvider.overrideWith(
            () => _FakeNotificationsController(),
          ),
          selectedBachelorProvider.overrideWithValue(null),
          openDayDataProvider.overrideWith(
            (ref) async => OpenDayData(
              openDayDate: DateTime(2026, 8, 22),
              lastUpdated: DateTime.now(),
              studyAreas: const [],
              bachelors: const [],
              events: const [],
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(SettingsPage));
    final l10n = AppLocalizations.of(context)!;

    await tester.scrollUntilVisible(
      find.text(l10n.settingsMyStampsTile),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text(l10n.settingsMyStampsTile));
    await tester.pumpAndSettle();

    expect(find.text('stamps-page'), findsOneWidget);
  });
}
