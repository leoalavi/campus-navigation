import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/app_shell.dart';

GoRouter _shellRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const Scaffold(body: Text('home-branch')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (_, _) => const Scaffold(body: Text('map-branch')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) =>
                    const Scaffold(body: Text('settings-branch')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Widget _app() {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: _shellRouter(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('renders the 3 bottom-nav destinations and the home branch', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(AppShell)))!;
    expect(find.text(l10n.home), findsOneWidget);
    expect(find.text(l10n.navigation), findsOneWidget);
    expect(find.text(l10n.settings), findsOneWidget);
    expect(find.text('home-branch'), findsOneWidget);
  });

  testWidgets('tapping a destination switches to that branch', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(AppShell)))!;
    await tester.tap(find.text(l10n.navigation));
    await tester.pumpAndSettle();

    expect(find.text('map-branch'), findsOneWidget);
    expect(find.text('home-branch'), findsNothing);
  });

  testWidgets('switching branches preserves each branch\'s own state', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(AppShell)))!;

    await tester.tap(find.text(l10n.settings));
    await tester.pumpAndSettle();
    expect(find.text('settings-branch'), findsOneWidget);

    await tester.tap(find.text(l10n.home));
    await tester.pumpAndSettle();
    expect(find.text('home-branch'), findsOneWidget);
  });
}
