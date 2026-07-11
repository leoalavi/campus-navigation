import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/data/adapters/settings_progress_api_adapter.dart';
import 'package:mq_journey/features/scan/application/pending_stamp_award_controller.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_progress_api.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/presentation/pages/scan_page.dart';
import 'package:mq_journey/features/scan/presentation/widgets/scanner_view.dart';
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
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ScanPage(),
    ),
  );
}

String _signedUri() {
  final manifest =
      jsonDecode(
            File('assets/qr/open_day/2026/manifest.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final locations = (manifest['locations'] as List)
      .cast<Map<String, dynamic>>();
  return locations.singleWhere(
        (entry) => entry['locationId'] == 'wallys-1',
      )['uri']
      as String;
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

  testWidgets('tampered signed input shows a semantic verification failure', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    final scannerView = tester.widget<ScannerView>(find.byType(ScannerView));
    scannerView.onDetect(_signedUri().replaceFirst('wallys-1', 'wallys-21'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('This QR code could not be verified'), findsOneWidget);
    final semantics = tester.getSemantics(
      find.text('This QR code could not be verified'),
    );
    expect(semantics.flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('first signed scan routes and queues a first-visit reward', (
    tester,
  ) async {
    final progressApi = FakeProgressApi();
    addTearDown(progressApi.dispose);

    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(path: '/scan', builder: (_, _) => const ScanPage()),
        GoRoute(
          path: '/location/:locationId',
          builder: (_, s) => Consumer(
            builder: (_, ref, _) => Scaffold(
              body: Text(
                'location-${s.pathParameters['locationId']}-'
                '${ref.watch(pendingStampAwardProvider)?.isNewVisit}',
              ),
            ),
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
    scannerView.onDetect(_signedUri());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('location-wallys-1-true'), findsOneWidget);
  });

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
          builder: (_, s) => Consumer(
            builder: (_, ref, _) => Scaffold(
              body: Text(
                'location-${s.pathParameters['locationId']}-'
                '${ref.watch(pendingStampAwardProvider)?.isNewVisit}',
              ),
            ),
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
    scannerView.onDetect(_signedUri());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('location-wallys-1-false'), findsOneWidget);
  });
}
