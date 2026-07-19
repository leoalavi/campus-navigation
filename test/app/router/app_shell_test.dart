import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/app_shell.dart';
import 'package:mq_journey/app/router/liquid_tab_bar.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';

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
                path: '/scan',
                builder: (_, _) => const Scaffold(body: Text('scan-branch')),
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
  testWidgets('tab bar is a glass LiquidTabBar over an extended body', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.extendBody, isTrue);

    expect(find.byType(LiquidTabBar), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(LiquidTabBar),
        matching: find.byType(GlassSurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders the 4 destinations (home active) and the home branch', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Home is selected -> filled icon; the rest show their outline icon.
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('home-branch'), findsOneWidget);
  });

  testWidgets('tapping the Journey destination switches to the map branch', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();

    expect(find.text('map-branch'), findsOneWidget);
    expect(find.text('home-branch'), findsNothing);
  });

  testWidgets('tapping the scan destination switches to the scan branch', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.qr_code_scanner_outlined));
    await tester.pumpAndSettle();

    expect(find.text('scan-branch'), findsOneWidget);
    expect(find.text('home-branch'), findsNothing);
  });

  testWidgets('switching branches preserves each branch\'s own state', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('settings-branch'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('home-branch'), findsOneWidget);
  });
}
