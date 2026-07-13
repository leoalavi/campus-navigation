import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';

import 'package:mq_journey/features/settings/data/repositories/settings_repository.dart';
import 'package:mq_journey/features/settings/presentation/pages/settings_page.dart';
import 'package:mq_journey/features/map/data/services/offline_maps_service.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/notifications/domain/entities/app_notification.dart';
import 'package:mq_journey/features/notifications/data/datasources/fcm_service.dart';
import 'package:mq_journey/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:mq_journey/features/transit/domain/entities/transit_stop.dart';
import 'package:mq_journey/features/transit/presentation/providers/tfnsw_provider.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockOfflineMapsService extends Mock implements OfflineMapsService {}

class _FakeNotificationsController extends NotificationsController {
  @override
  Future<NotificationsState> build() async {
    return const NotificationsState(
      permissionStatus: NotificationPermissionStatus.granted,
      preferences: [],
    );
  }

  @override
  Future<void> updatePreference(NotificationType type, bool enabled) async {
    // No-op for testing
  }
}

void main() {
  late MockSettingsRepository mockSettingsRepository;
  late MockOfflineMapsService mockOfflineMapsService;

  setUpAll(() {
    registerFallbackValue(const UserPreferences());
  });

  setUp(() {
    mockSettingsRepository = MockSettingsRepository();
    mockOfflineMapsService = MockOfflineMapsService();

    when(
      () => mockSettingsRepository.loadPreferences(),
    ).thenAnswer((_) async => const UserPreferences());
    when(() => mockSettingsRepository.savePreferences(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments[0] as UserPreferences,
    );
    when(
      () => mockSettingsRepository.wipeAllLocalData(),
    ).thenAnswer((_) async {});

    when(() => mockOfflineMapsService.isFmtcBackendReady).thenReturn(false);
    when(
      () => mockOfflineMapsService.downloadCampusTiles(),
    ).thenAnswer((_) async => true);
  });

  Widget buildTestApp({Widget? child}) {
    return ProviderScope(
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
        tfnswStopSearchProvider.overrideWith((ref, search) async {
          return [
            const TransitStop(
              id: '10101403',
              name: 'Macquarie University Station',
            ),
            const TransitStop(id: '211310', name: 'Macquarie Park Station'),
          ];
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child ?? const SettingsPage(),
      ),
    );
  }

  void setupLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('SettingsPage Widget Tests', () {
    testWidgets('renders all preference categories', (tester) async {
      setupLargeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(SettingsPage));
      final l10n = AppLocalizations.of(context)!;

      // Verify page title
      expect(find.text(l10n.settings.toUpperCase()), findsOneWidget);

      // Verify key section labels exist
      expect(find.text(l10n.settings_general.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.commutePreferences.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.openDay_section.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.accessibility.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.notifications.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.about.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.dangerZone.toUpperCase()), findsOneWidget);
    });

    testWidgets('positions MQ Journey as an Open Day companion', (
      tester,
    ) async {
      setupLargeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(
        find.text('Macquarie University Open Day companion'),
        findsOneWidget,
      );
      expect(find.textContaining('MQ Journey Open Day team'), findsOneWidget);
      expect(find.textContaining('Campus Management'), findsNothing);
      expect(find.textContaining('COMP3130'), findsNothing);
    });

    testWidgets('toggling haptics switch invokes repository savePreferences', (
      tester,
    ) async {
      setupLargeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(SettingsPage));
      final l10n = AppLocalizations.of(context)!;

      final hapticsTextFinder = find.text(l10n.haptics);
      expect(hapticsTextFinder, findsOneWidget);

      final rowFinder = find.ancestor(
        of: hapticsTextFinder,
        matching: find.byType(Row),
      );
      final switchFinder = find.descendant(
        of: rowFinder,
        matching: find.byType(Switch),
      );
      expect(switchFinder, findsOneWidget);

      // Tap on the switch
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify settings repository saved the new preference (hapticsEnabled should toggle to false since default is true)
      verify(
        () => mockSettingsRepository.savePreferences(
          any(
            that: isA<UserPreferences>().having(
              (p) => p.hapticsEnabled,
              'hapticsEnabled',
              isFalse,
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets(
      'Wipe Local Data displays confirmation dialog and triggers repository wipe on confirm',
      (tester) async {
        setupLargeViewport(tester);
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        final BuildContext context = tester.element(find.byType(SettingsPage));
        final l10n = AppLocalizations.of(context)!;

        final wipeDataFinder = find.text(l10n.wipeData);
        expect(wipeDataFinder, findsOneWidget);

        await tester.tap(wipeDataFinder);
        await tester.pumpAndSettle();

        // Dialog should be visible
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.wipeDataConfirm),
          ),
          findsOneWidget,
        );

        // Tap cancel
        final cancelFinder = find.text(l10n.cancel);
        expect(cancelFinder, findsOneWidget);
        await tester.tap(cancelFinder);
        await tester.pumpAndSettle();

        // Dialog should be dismissed, and repository wipe should NOT have been called
        expect(find.byType(AlertDialog), findsNothing);
        verifyNever(() => mockSettingsRepository.wipeAllLocalData());

        // Open dialog again
        await tester.tap(wipeDataFinder);
        await tester.pumpAndSettle();

        // Tap confirm (l10n.wipeDataAction)
        final confirmFinder = find.text(l10n.wipeDataAction);
        expect(confirmFinder, findsOneWidget);
        await tester.tap(confirmFinder);
        await tester.pumpAndSettle();

        // Dialog dismissed, repository wipe called once, success snackbar shown
        expect(find.byType(AlertDialog), findsNothing);
        verify(() => mockSettingsRepository.wipeAllLocalData()).called(1);
        expect(find.text(l10n.wipeDataSuccess), findsOneWidget);
      },
    );
  });
}
