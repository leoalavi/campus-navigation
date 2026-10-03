import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/features/auth/data/repositories/auth_repository.dart';
import 'package:mq_navigation/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mq_navigation/features/favorites/data/repositories/favorite_building_repository.dart';
import 'package:mq_navigation/features/favorites/domain/entities/favorite_building.dart';
import 'package:mq_navigation/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:mq_navigation/features/map/presentation/pages/favorites_page.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockFavoriteBuildingRepository extends Mock
    implements FavoriteBuildingRepository {}

final _now = DateTime.now();

final _sampleFav = FavoriteBuilding(
  id: 'fav-1',
  userId: 'user-1',
  buildingId: 'BLD',
  buildingName: 'Library',
  note: null,
  createdAt: _now,
  updatedAt: _now,
);

final _sampleFav2 = FavoriteBuilding(
  id: 'fav-2',
  userId: 'user-1',
  buildingId: 'SCI',
  buildingName: 'Science Building',
  note: null,
  createdAt: _now,
  updatedAt: _now,
);

Widget buildApp({
  required AuthRepository authRepository,
  required FavoriteBuildingRepository favRepository,
}) {
  final router = GoRouter(
    initialLocation: '/favorites',
    routes: [
      GoRoute(path: '/favorites', builder: (_, _) => const FavoritesPage()),
      GoRoute(
        path: '/map/building/:buildingId',
        builder: (_, state) => Scaffold(
          body: Text('Building ${state.pathParameters['buildingId']}'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      favoriteBuildingRepositoryProvider.overrideWithValue(favRepository),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockFavoriteBuildingRepository mockFavRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockFavRepo = MockFavoriteBuildingRepository();
    when(() => mockAuthRepo.userId).thenReturn('user-1');
    // FavoritesController.build() now calls ref.listen(authControllerProvider),
    // which triggers AuthController.build() → mockAuthRepo.isAuthenticated.
    when(() => mockAuthRepo.isAuthenticated).thenReturn(false);
  });

  // The Edit-note dialog auto-focuses a TextField. Flutter's default
  // test surface (800x600) sometimes triggers caret-positioning
  // assertions on the EditableText render object before the dialog
  // is fully attached — explicit surface sizing avoids that race.
  Future<void> setLargeSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('shows loading indicator immediately', (tester) async {
    // The load is called in initState via postFrameCallback.
    // Since the controller starts with isLoading=false, the loading
    // spinner only shows while load() is in-flight. We test that
    // the spinner appears by not completing the fetchAll future.
    late Completer<void> neverComplete;
    neverComplete = Completer<void>();
    when(() => mockFavRepo.fetchAll(userId: any(named: 'userId'))).thenAnswer(
      (_) => neverComplete.future.then((_) => FavoritesResult.success([])),
    );

    await tester.pumpWidget(
      buildApp(authRepository: mockAuthRepo, favRepository: mockFavRepo),
    );
    // First pump: build, postFrameCallback schedules load
    await tester.pump();
    // Second pump: load starts, isLoading transitions through true
    await tester.pump();

    // The load is in-flight so isLoading should be true
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error state with retry button', (tester) async {
    when(() => mockFavRepo.fetchAll(userId: any(named: 'userId'))).thenAnswer(
      (_) async => FavoritesResult.failure('Could not load favorites.'),
    );

    await tester.pumpWidget(
      buildApp(authRepository: mockAuthRepo, favRepository: mockFavRepo),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Could not load favorites.'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('shows empty state when no favorites', (tester) async {
    when(
      () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
    ).thenAnswer((_) async => FavoritesResult.success([]));

    await tester.pumpWidget(
      buildApp(authRepository: mockAuthRepo, favRepository: mockFavRepo),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
  });

  testWidgets('shows list of favorited buildings', (tester) async {
    when(() => mockFavRepo.fetchAll(userId: any(named: 'userId'))).thenAnswer(
      (_) async => FavoritesResult.success([_sampleFav, _sampleFav2]),
    );

    await tester.pumpWidget(
      buildApp(authRepository: mockAuthRepo, favRepository: mockFavRepo),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Science Building'), findsOneWidget);
    expect(find.text('BLD'), findsOneWidget);
    expect(find.text('SCI'), findsOneWidget);
  });

  testWidgets('subtitle shows note when present (italic)', (tester) async {
    final favWithNote = FavoriteBuilding(
      id: 'fav-3',
      userId: 'user-1',
      buildingId: 'LIB',
      buildingName: 'Library',
      note: 'Group study area is on level 4',
      createdAt: _now,
      updatedAt: _now,
    );
    when(
      () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
    ).thenAnswer((_) async => FavoritesResult.success([favWithNote]));

    await tester.pumpWidget(
      buildApp(authRepository: mockAuthRepo, favRepository: mockFavRepo),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Group study area is on level 4'), findsOneWidget);
    // When a note is shown, the building code is hidden (note takes the row).
    expect(find.text('LIB'), findsNothing);
  });

  testWidgets('kebab menu surfaces Edit and Remove actions', (tester) async {
    when(
      () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
    ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));

    await tester.pumpWidget(
      buildApp(authRepository: mockAuthRepo, favRepository: mockFavRepo),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Open the kebab menu.
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();

    // _sampleFav has no note, so the label should be "Add note"
    expect(find.text('Add note'), findsOneWidget);
    // Popup menu shows "Remove" (not "Yes, remove" — that's the confirm dialog)
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('edit note dialog persists changes via repository', (
    tester,
  ) async {
    await setLargeSurface(tester);
    final updated = _sampleFav.copyWith(note: 'New note text');
    when(
      () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
    ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));
    when(
      () => mockFavRepo.updateNote(
        id: any(named: 'id'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async => FavoritesResult.success(updated));

    await tester.pumpWidget(
      buildApp(authRepository: mockAuthRepo, favRepository: mockFavRepo),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    // _sampleFav has no note, so the popup shows "Add note"
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    // Dialog text field is auto-focused — type the new note.
    await tester.enterText(find.byType(TextField), 'New note text');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(
      () => mockFavRepo.updateNote(id: 'fav-1', note: 'New note text'),
    ).called(1);
  });

  testWidgets('remove action shows confirm dialog and calls repository', (
    tester,
  ) async {
    when(
      () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
    ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));
    when(
      () => mockFavRepo.remove(any()),
    ).thenAnswer((_) async => FavoritesResult.success(null));

    await tester.pumpWidget(
      buildApp(authRepository: mockAuthRepo, favRepository: mockFavRepo),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Open kebab → tap the popup-menu "Remove" item.
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // The confirm dialog now asks for explicit confirmation.
    expect(find.text('Remove this favourite?'), findsOneWidget);
    // After the menu closes there is only one "Yes, remove" — the
    // confirm button. No `.last` ambiguity needed.
    await tester.tap(find.text('Yes, remove'));
    await tester.pumpAndSettle();

    verify(() => mockFavRepo.remove('fav-1')).called(1);
  });

  testWidgets('edit dialog cancel does not call updateNote', (tester) async {
    await setLargeSurface(tester);
    when(
      () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
    ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));

    await tester.pumpWidget(
      buildApp(authRepository: mockAuthRepo, favRepository: mockFavRepo),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    // _sampleFav has no note, so the popup shows "Add note"
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Typed but cancelled');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mockFavRepo.updateNote(
        id: any(named: 'id'),
        note: any(named: 'note'),
      ),
    );
  });

  testWidgets('retry button reloads on error state', (tester) async {
    when(() => mockFavRepo.fetchAll(userId: any(named: 'userId'))).thenAnswer(
      (_) async => FavoritesResult.failure('Could not load favorites.'),
    );

    await tester.pumpWidget(
      buildApp(authRepository: mockAuthRepo, favRepository: mockFavRepo),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Could not load favorites.'), findsOneWidget);

    when(
      () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
    ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Library'), findsOneWidget);
  });
}
