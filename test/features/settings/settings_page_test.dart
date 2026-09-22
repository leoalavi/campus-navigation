import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/features/settings/data/repositories/settings_repository.dart';
import 'package:mq_navigation/features/settings/presentation/pages/settings_page.dart';
import 'package:mq_navigation/features/map/data/services/offline_maps_service.dart';
import 'package:mq_navigation/features/open_day/data/open_day_providers.dart';
import 'package:mq_navigation/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_navigation/features/notifications/domain/entities/app_notification.dart';
import 'package:mq_navigation/features/notifications/data/datasources/fcm_service.dart';
import 'package:mq_navigation/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:mq_navigation/features/transit/domain/entities/transit_stop.dart';
import 'package:mq_navigation/features/transit/presentation/providers/tfnsw_provider.dart';
import 'package:mq_navigation/shared/models/user_preferences.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockOfflineMapsService extends Mock implements OfflineMapsService {}

/// The real platform implementation, restored after each test that swaps in
/// [_FakeUrlLauncher] — otherwise later tests (or other files sharing this
/// isolate) would keep talking to the fake.
final _originalUrlLauncher = UrlLauncherPlatform.instance;

/// Records the last URL the ecosystem row asked to open, instead of hitting
/// a real (nonexistent in the test environment) platform channel.
class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  String? launchedUrl;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    return true;
  }
}

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

    // Default mock behavior

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
    ).thenAnswer((_) async {});
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
            openDayDate: DateTime(2027, 8, 14),
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
      expect(find.text(l10n.settings_experience.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.commutePreferences.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.openDay_section.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.accessibility.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.notifications.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.about.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.dangerZone.toUpperCase()), findsOneWidget);
    });

    testWidgets('About shows subtle Syllabus Sync ecosystem attribution', (
      tester,
    ) async {
      // Smallest common iPhone width (SE / mini) — the tightest layout the
      // three-line row + logo + external-link glyph has to fit without
      // overflowing.
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      final title = find.text('Part of the Syllabus Sync ecosystem');
      await tester.scrollUntilVisible(title, 500);
      await tester.pumpAndSettle();

      expect(title, findsOneWidget);
      expect(
        find.text('Campus Navigation is part of the Syllabus Sync ecosystem.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Built to work seamlessly with Syllabus Sync through shared '
          'navigation and deep-linking.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('about-syllabus-sync-logo')),
        findsOneWidget,
      );
      // The Campus Navigation identity itself is unaffected by the ecosystem
      // row: the app name still renders, and the Syllabus Sync logo does not
      // appear anywhere else on the page (e.g. duplicated at the top of About).
      expect(find.text('Campus Navigation'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('about-syllabus-sync-logo')),
        findsOneWidget,
      );

      // No RenderFlex overflow (or any other) exception on the tightest
      // supported width.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'ecosystem row exposes a tappable semantics node with a sensible label',
      (tester) async {
        final handle = tester.ensureSemantics();

        setupLargeViewport(tester);
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        final title = find.text('Part of the Syllabus Sync ecosystem');
        await tester.scrollUntilVisible(title, 500);
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.bySemanticsLabel(
            RegExp('Part of the Syllabus Sync ecosystem.*'),
          ),
        );
        expect(
          node.flagsCollection.isButton,
          isTrue,
          reason: 'ecosystem row must announce itself as tappable',
        );
        expect(node.label, contains('Part of the Syllabus Sync ecosystem'));
        expect(node.label, contains('Campus Navigation is part of'));
        handle.dispose();
      },
    );

    testWidgets('tapping the ecosystem row opens the Syllabus Sync site', (
      tester,
    ) async {
      final fakeLauncher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = fakeLauncher;
      addTearDown(() => UrlLauncherPlatform.instance = _originalUrlLauncher);

      setupLargeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final title = find.text('Part of the Syllabus Sync ecosystem');
      await tester.scrollUntilVisible(title, 500);
      await tester.pumpAndSettle();

      await tester.tap(title);
      await tester.pumpAndSettle();

      expect(fakeLauncher.launchedUrl, 'https://syllabus-sync.app');
      expect(tester.takeException(), isNull);
    });

    testWidgets('puts Main Transport before the commute summary', (
      tester,
    ) async {
      setupLargeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final transport = find.byKey(
        const ValueKey('commute-main-transport-card'),
      );
      final summary = find.byKey(const ValueKey('commute-summary-card'));
      expect(transport, findsOneWidget);
      expect(summary, findsOneWidget);
      expect(
        tester.getTopLeft(transport).dy,
        lessThan(tester.getTopLeft(summary).dy),
      );
    });

    testWidgets('preferred-stop search shows and selects real results', (
      tester,
    ) async {
      setupLargeViewport(tester);
      when(
        () => mockSettingsRepository.loadPreferences(),
      ).thenAnswer((_) async => const UserPreferences(commuteMode: 'metro'));
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(SettingsPage));
      final l10n = AppLocalizations.of(context)!;
      final preferredStop = find.text(l10n.favoriteStopIdLabel);
      await tester.ensureVisible(preferredStop);
      await tester.tap(preferredStop);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, 'Macquarie');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Macquarie University Station'), findsOneWidget);

      await tester.tap(find.text('Macquarie University Station'));
      await tester.pumpAndSettle();
      verify(
        () => mockSettingsRepository.savePreferences(
          any(
            that: isA<UserPreferences>()
                .having((p) => p.favoriteStopId, 'favoriteStopId', '10101403')
                .having(
                  (p) => p.favoriteStopName,
                  'favoriteStopName',
                  'Macquarie University Station',
                ),
          ),
        ),
      ).called(1);
    });

    // Campus Navigation has no accounts: Settings must offer no sign-in,
    // sign-out or account identity at all.
    testWidgets('exposes no account or sign-out surface', (tester) async {
      setupLargeViewport(tester);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(SettingsPage));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.account.toUpperCase()), findsNothing);
      expect(find.text(l10n.signOut), findsNothing);
      expect(find.text(l10n.signedInAs), findsNothing);
      expect(find.text(l10n.notSignedInLabel), findsNothing);
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
