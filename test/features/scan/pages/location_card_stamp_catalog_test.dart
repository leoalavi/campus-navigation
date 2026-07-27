import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/application/pending_stamp_award_controller.dart';
import 'package:mq_journey/features/scan/domain/contracts/location_content.dart';
import 'package:mq_journey/features/scan/domain/contracts/schedule_provider.dart';
import 'package:mq_journey/features/scan/domain/contracts/schedule_slot.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_my_day_api.dart';
import 'package:mq_journey/features/scan/domain/models/buildings_registry.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/presentation/pages/location_card_page.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_earned_sheet.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/settings/data/repositories/settings_repository.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';
import 'package:riverpod/misc.dart' show Override;

/// The pending stamp award must survive a catalog that fails or hangs.
///
/// Consuming the notice up front meant a failed catalog threw the award away
/// with nothing on screen and no way to recover it. The award is now peeked
/// and only consumed once the catalog has actually answered.

class _NoSchedule implements ScheduleProvider {
  @override
  ScheduleSlot? liveNow(String id) => null;
  @override
  ScheduleSlot? comingUpNext(String id) => null;
}

class MockSettingsRepository extends Mock implements SettingsRepository {}

const _trail = TrailManifest(
  locations: [
    TrailLocation(
      locationId: 'wallys-1',
      buildingId: 'wallys-1',
      title: "1 Wally's Walk",
      photos: ['assets/photos/_placeholder.jpg'],
    ),
  ],
);

const _registry = BuildingsRegistry(
  buildings: [
    BuildingEntry(
      code: 'wallys-1',
      name: "1 Wally's Walk",
      campusX: 0,
      campusY: 0,
      entranceLatitude: -33.7747,
      entranceLongitude: 151.1142,
    ),
  ],
);

const _catalog = [
  StampCatalogEntry(
    locationId: 'wallys-1',
    title: "1 Wally's Walk",
    mapRef: 'K27',
    stampAsset: 'assets/stamps/wallys-1.png',
  ),
];

Widget _app() {
  final router = GoRouter(
    initialLocation: '/location/wallys-1',
    routes: [
      GoRoute(
        path: '/location/:locationId',
        builder: (_, s) =>
            LocationCardPage(locationId: s.pathParameters['locationId']!),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

List<Override> _base(MockSettingsRepository repo) => [
  settingsRepositoryProvider.overrideWithValue(repo),
  trailManifestProvider.overrideWith((ref) async => _trail),
  buildingsRegistryProvider.overrideWith((ref) async => _registry),
  locationContentProvider.overrideWith(
    (ref, id) => LocationContent(
      locationId: id,
      title: "1 Wally's Walk",
      heroImageAsset: 'assets/images/placeholder_hero.png',
      shortDescription: 'One. Two. Three.',
      buildingId: 'wallys-1',
    ),
  ),
  scheduleProvider.overrideWith((ref) => _NoSchedule()),
  visitedStateProvider.overrideWith(
    (ref, id) =>
        Stream.value(const VisitedState(visited: false, rewardEarned: false)),
  ),
  myDayApiProvider.overrideWith((ref) => FakeMyDayApi()),
];

/// A catalog that fails does not surface as `AsyncError` in the vendored
/// Riverpod — it stays `AsyncLoading` — so failure paths only resolve once
/// [kStampCatalogTimeout] fires.
Future<void> _settleCatalog(WidgetTester tester) async {
  await tester.pump(kStampCatalogTimeout + const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  late MockSettingsRepository repo;

  setUp(() {
    repo = MockSettingsRepository();
    when(() => repo.loadPreferences()).thenAnswer(
      (_) async => const UserPreferences(visitedLocationCodes: ['WALLYS-1']),
    );
  });

  ProviderContainer containerWith(
    Future<List<StampCatalogEntry>> Function() catalog, {
    bool isNewVisit = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        stampCatalogProvider.overrideWith((ref) => catalog()),
        ..._base(repo),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(pendingStampAwardProvider.notifier)
        .setNotice(
          PendingStampNotice(locationId: 'wallys-1', isNewVisit: isNewVisit),
        );
    return container;
  }

  String errorCopy(WidgetTester tester) => AppLocalizations.of(
    tester.element(find.byType(LocationCardPage)),
  )!.stampCatalogUnavailable;

  String retryCopy(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(LocationCardPage)))!.retry;

  testWidgets('1. catalog loads — the award sheet appears and is consumed', (
    tester,
  ) async {
    final container = containerWith(() async => _catalog);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _app()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(StampEarnedSheet), findsOneWidget);
    expect(container.read(pendingStampAwardProvider), isNull);
  });

  testWidgets('2. catalog throws — error shown, award kept', (tester) async {
    final container = containerWith(
      () async => throw Exception('catalog missing'),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _app()),
    );
    await tester.pump();
    await _settleCatalog(tester);

    expect(find.text(errorCopy(tester)), findsOneWidget);
    expect(find.byType(StampEarnedSheet), findsNothing);
    expect(
      container.read(pendingStampAwardProvider),
      isNotNull,
      reason: 'a failed catalog must not swallow the award',
    );
  });

  testWidgets('3. catalog never settles — bounded, error shown, award kept', (
    tester,
  ) async {
    final stuck = Completer<List<StampCatalogEntry>>();
    final container = containerWith(() => stuck.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _app()),
    );
    await tester.pump();

    // Still waiting: nothing decided, award still pending.
    expect(find.byType(StampEarnedSheet), findsNothing);
    expect(container.read(pendingStampAwardProvider), isNotNull);

    await _settleCatalog(tester);

    expect(find.text(errorCopy(tester)), findsOneWidget);
    expect(container.read(pendingStampAwardProvider), isNotNull);
  });

  testWidgets('4. Retry re-reads the catalog and completes the award', (
    tester,
  ) async {
    var down = true;
    var reads = 0;
    final container = containerWith(() async {
      reads++;
      if (down) throw Exception('transient');
      return _catalog;
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _app()),
    );
    await tester.pump();
    await _settleCatalog(tester);
    expect(find.text(retryCopy(tester)), findsOneWidget);

    final before = reads;
    down = false;
    await tester.tap(find.text(retryCopy(tester)));
    // Fixed pumps, not pumpAndSettle: the celebration sheet animates
    // continuously while open, so settling never completes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(reads, greaterThan(before));
    expect(find.byType(StampEarnedSheet), findsOneWidget);
    expect(container.read(pendingStampAwardProvider), isNull);
  });

  testWidgets('5. pending award survives failure and is not lost', (
    tester,
  ) async {
    final container = containerWith(() async => throw Exception('down'));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _app()),
    );
    await tester.pump();
    await _settleCatalog(tester);

    final pending = container.read(pendingStampAwardProvider);
    expect(pending, isNotNull);
    expect(pending!.locationId, 'wallys-1');
    expect(
      pending.isNewVisit,
      isTrue,
      reason: 'the award must be preserved intact, not downgraded',
    );
  });

  testWidgets('6. a duplicate visit still reports "already collected"', (
    tester,
  ) async {
    // Dedup is driven by locally-persisted visited codes, not by the notice,
    // so it must survive the peek/consume rework.
    final container = containerWith(() async => _catalog, isNewVisit: false);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _app()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = AppLocalizations.of(
      tester.element(find.byType(LocationCardPage)),
    )!;
    expect(
      find.text(l10n.stampAlreadyCollected("1 Wally's Walk")),
      findsOneWidget,
    );
    expect(find.byType(StampEarnedSheet), findsNothing);
    expect(container.read(pendingStampAwardProvider), isNull);
  });

  testWidgets('7. dismissing the error does not consume the award', (
    tester,
  ) async {
    final container = containerWith(() async => throw Exception('down'));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _app()),
    );
    await tester.pump();
    await _settleCatalog(tester);
    expect(container.read(pendingStampAwardProvider), isNotNull);

    // Let the SnackBar time out on its own — closing the error is not an
    // acknowledgement that the award was delivered.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(
      container.read(pendingStampAwardProvider),
      isNotNull,
      reason: 'dismissing the error must leave the award pending',
    );
  });
}
