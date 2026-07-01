import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/home/presentation/pages/onboarding_page.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class _FakeSettingsController extends SettingsController {
  UserPreferences _prefs = const UserPreferences();
  bool completedCalled = false;

  @override
  Future<UserPreferences> build() async => _prefs;

  @override
  Future<String?> completeOnboarding() async {
    completedCalled = true;
    _prefs = _prefs.copyWith(hasCompletedOnboarding: true);
    state = AsyncData(_prefs);
    return null;
  }
}

Widget _app({
  required GoRouter router,
  required _FakeSettingsController controller,
}) {
  return ProviderScope(
    overrides: [settingsControllerProvider.overrideWith(() => controller)],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (_, _) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (_, _) => const Scaffold(body: Text('home-page')),
      ),
    ],
  );
}

void main() {
  testWidgets('shows the first slide title on launch', (tester) async {
    final controller = _FakeSettingsController();
    await tester.pumpWidget(_app(router: _router(), controller: controller));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(OnboardingPage)),
    )!;
    expect(find.text(l10n.onboardingMapTitle), findsOneWidget);
  });

  testWidgets('tapping Skip completes onboarding and navigates home', (
    tester,
  ) async {
    final controller = _FakeSettingsController();
    await tester.pumpWidget(_app(router: _router(), controller: controller));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(OnboardingPage)),
    )!;
    await tester.tap(find.text(l10n.onboardingSkip));
    await tester.pumpAndSettle();

    expect(controller.completedCalled, isTrue);
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets(
    'tapping Next advances through slides, then completes on the last',
    (tester) async {
      final controller = _FakeSettingsController();
      await tester.pumpWidget(_app(router: _router(), controller: controller));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(OnboardingPage)),
      )!;

      // 4 slides total: map, transit, open day, privacy — tap Next 3 times to
      // reach the last slide, then a 4th time to finish.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text(l10n.onboardingNext));
        await tester.pumpAndSettle();
      }

      expect(find.text(l10n.onboardingPrivacyTitle), findsOneWidget);
      expect(find.text(l10n.onboardingStart), findsOneWidget);

      await tester.tap(find.text(l10n.onboardingStart));
      await tester.pumpAndSettle();

      expect(controller.completedCalled, isTrue);
      expect(find.text('home-page'), findsOneWidget);
    },
  );
}
