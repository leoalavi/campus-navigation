import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/data/adapters/settings_progress_api_adapter.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_progress_api.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/presentation/pages/scan_page.dart';
import 'package:mq_journey/features/scan/presentation/widgets/scanner_view.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_earned_sheet.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';

const _fixtureManifest = TrailManifest(
  locations: [
    TrailLocation(
      locationId: 'wallys-1',
      buildingId: 'wallys-1',
      title: "1 Wally's Walk",
    ),
  ],
);

const _fixtureCatalog = [
  StampCatalogEntry(
    locationId: 'wallys-1',
    title: "1 Wally's Walk",
    mapRef: 'K27',
    stampAsset: 'assets/stamps/wallys-1.png',
  ),
];

Widget _buildTestApp() {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ScanPage(),
    ),
  );
}

void main() {
  testWidgets('renders scan page with app bar', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    expect(find.byType(ScanPage), findsOneWidget);
  });

  testWidgets('shows torch toggle in scanning state', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    expect(find.byIcon(Icons.flash_off), findsOneWidget);
  });

  testWidgets('lifecycle disposes controller cleanly', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(find.byType(ScanPage), findsNothing);
  });

  testWidgets(
    'first scan of a catalogued location shows the celebration sheet',
    (tester) async {
      final progressApi = FakeProgressApi();
      addTearDown(progressApi.dispose);

      final router = GoRouter(
        initialLocation: '/scan',
        routes: [
          GoRoute(path: '/scan', builder: (_, _) => const ScanPage()),
          GoRoute(
            path: '/location/:locationId',
            builder: (_, s) => Scaffold(
              body: Text('location-${s.pathParameters['locationId']}'),
            ),
          ),
          GoRoute(
            path: '/stamps',
            builder: (_, _) => const Scaffold(body: Text('stamps-page')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressApiProvider.overrideWithValue(progressApi),
            stampCatalogProvider.overrideWith((ref) async => _fixtureCatalog),
            trailManifestProvider.overrideWith((ref) async => _fixtureManifest),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      final scannerView = tester.widget<ScannerView>(find.byType(ScannerView));
      scannerView.onDetect('https://mq.edu.au/scan?locationId=wallys-1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(StampEarnedSheet), findsOneWidget);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(StampEarnedSheet)),
      )!;
      await tester.tap(find.text(l10n.stampCelebrationKeepExploring));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('location-wallys-1'), findsOneWidget);
    },
  );

  testWidgets('re-scanning an already-collected location skips the sheet', (
    tester,
  ) async {
    final progressApi = FakeProgressApi();
    addTearDown(progressApi.dispose);
    // Pre-seed the visit so the second scan is a repeat.
    await progressApi.recordVisit(
      VisitEvent(locationId: 'wallys-1', scannedAt: DateTime.now()),
    );

    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(path: '/scan', builder: (_, _) => const ScanPage()),
        GoRoute(
          path: '/location/:locationId',
          builder: (_, s) => Scaffold(
            body: Text('location-${s.pathParameters['locationId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressApiProvider.overrideWithValue(progressApi),
          stampCatalogProvider.overrideWith((ref) async => _fixtureCatalog),
          trailManifestProvider.overrideWith((ref) async => _fixtureManifest),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();

    final scannerView = tester.widget<ScannerView>(find.byType(ScannerView));
    scannerView.onDetect('https://mq.edu.au/scan?locationId=wallys-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(StampEarnedSheet), findsNothing);
    expect(find.text('location-wallys-1'), findsOneWidget);
  });
}
