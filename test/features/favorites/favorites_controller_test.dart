import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_navigation/core/network/session_guard.dart';
import 'package:mq_navigation/features/auth/data/repositories/auth_repository.dart';
import 'package:mq_navigation/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mq_navigation/features/favorites/data/repositories/favorite_building_repository.dart';
import 'package:mq_navigation/features/favorites/domain/entities/favorite_building.dart';
import 'package:mq_navigation/features/favorites/presentation/controllers/favorites_controller.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockFavoriteBuildingRepository extends Mock
    implements FavoriteBuildingRepository {}

final _now = DateTime.now();

final _sampleFav = FavoriteBuilding(
  id: 'fav-1',
  userId: 'user-1',
  buildingId: 'BLD',
  buildingName: 'Test Building',
  note: null,
  createdAt: _now,
  updatedAt: _now,
);

ProviderContainer makeContainer({
  required AuthRepository authRepository,
  required FavoriteBuildingRepository favRepository,
}) {
  return ProviderContainer(
    overrides: [
      sessionGuardProvider.overrideWithValue(() async => true),
      authRepositoryProvider.overrideWithValue(authRepository),
      favoriteBuildingRepositoryProvider.overrideWithValue(favRepository),
    ],
  );
}

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockFavoriteBuildingRepository mockFavRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockFavRepo = MockFavoriteBuildingRepository();
    // FavoritesController.build() now calls ref.listen(authControllerProvider),
    // which triggers AuthController.build() → mockAuthRepo.isAuthenticated.
    // Stub it here so tests don't need Supabase initialised.
    when(() => mockAuthRepo.isAuthenticated).thenReturn(false);
  });

  group('initial state', () {
    test('is not loading with empty favorites', () {
      when(() => mockAuthRepo.userId).thenReturn('user-1');

      final container = makeContainer(
        authRepository: mockAuthRepo,
        favRepository: mockFavRepo,
      );
      addTearDown(() => container.dispose());

      final state = container.read(favoritesControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.favorites, isEmpty);
      expect(state.error, isNull);
    });
  });

  group('load', () {
    test('loads favorites for authenticated user', () async {
      when(() => mockAuthRepo.userId).thenReturn('user-1');
      when(
        () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
      ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));

      final container = makeContainer(
        authRepository: mockAuthRepo,
        favRepository: mockFavRepo,
      );
      addTearDown(() => container.dispose());

      await container.read(favoritesControllerProvider.notifier).load();

      final state = container.read(favoritesControllerProvider);
      expect(state.favorites, hasLength(1));
      expect(state.favoritedBuildingIds, contains('BLD'));
    });

    test('sets error on failure', () async {
      when(() => mockAuthRepo.userId).thenReturn('user-1');
      when(() => mockFavRepo.fetchAll(userId: any(named: 'userId'))).thenAnswer(
        (_) async => FavoritesResult.failure('Could not load favourites.'),
      );

      final container = makeContainer(
        authRepository: mockAuthRepo,
        favRepository: mockFavRepo,
      );
      addTearDown(() => container.dispose());

      await container.read(favoritesControllerProvider.notifier).load();

      final state = container.read(favoritesControllerProvider);
      expect(state.error, isNotNull);
      expect(state.favorites, isEmpty);
    });
  });

  group('toggle', () {
    test('adds when not favorited', () async {
      when(() => mockAuthRepo.userId).thenReturn('user-1');
      when(
        () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
      ).thenAnswer((_) async => FavoritesResult.success([]));
      when(
        () => mockFavRepo.findFavoriteId(
          userId: any(named: 'userId'),
          buildingId: any(named: 'buildingId'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockFavRepo.add(
          userId: any(named: 'userId'),
          buildingId: any(named: 'buildingId'),
          buildingName: any(named: 'buildingName'),
        ),
      ).thenAnswer((_) async => FavoritesResult.success(_sampleFav));
      // Reload after toggle returns the new list
      when(
        () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
      ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));

      final container = makeContainer(
        authRepository: mockAuthRepo,
        favRepository: mockFavRepo,
      );
      addTearDown(() => container.dispose());

      await container
          .read(favoritesControllerProvider.notifier)
          .toggle(buildingId: 'BLD', buildingName: 'Test Building');

      verify(
        () => mockFavRepo.add(
          userId: any(named: 'userId'),
          buildingId: any(named: 'buildingId'),
          buildingName: any(named: 'buildingName'),
        ),
      ).called(1);
    });

    test('removes when already favorited', () async {
      when(() => mockAuthRepo.userId).thenReturn('user-1');
      when(
        () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
      ).thenAnswer((_) async => FavoritesResult.success([]));
      when(
        () => mockFavRepo.findFavoriteId(
          userId: any(named: 'userId'),
          buildingId: any(named: 'buildingId'),
        ),
      ).thenAnswer((_) async => 'fav-1');
      when(
        () => mockFavRepo.remove(any()),
      ).thenAnswer((_) async => FavoritesResult.success(null));

      final container = makeContainer(
        authRepository: mockAuthRepo,
        favRepository: mockFavRepo,
      );
      addTearDown(() => container.dispose());

      await container
          .read(favoritesControllerProvider.notifier)
          .toggle(buildingId: 'BLD', buildingName: 'Test Building');

      verify(() => mockFavRepo.remove('fav-1')).called(1);
    });
  });

  group('remove', () {
    test('removes a favorite by id', () async {
      when(() => mockAuthRepo.userId).thenReturn('user-1');
      when(
        () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
      ).thenAnswer((_) async => FavoritesResult.success([]));
      when(
        () => mockFavRepo.remove(any()),
      ).thenAnswer((_) async => FavoritesResult.success(null));

      final container = makeContainer(
        authRepository: mockAuthRepo,
        favRepository: mockFavRepo,
      );
      addTearDown(() => container.dispose());

      await container
          .read(favoritesControllerProvider.notifier)
          .remove('fav-1');

      verify(() => mockFavRepo.remove('fav-1')).called(1);
    });
  });

  group('updateNote', () {
    test('updates note', () async {
      when(() => mockAuthRepo.userId).thenReturn('user-1');
      when(
        () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
      ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));
      final updated = _sampleFav.copyWith(note: 'my note');
      when(
        () => mockFavRepo.updateNote(
          id: any(named: 'id'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => FavoritesResult.success(updated));

      final container = makeContainer(
        authRepository: mockAuthRepo,
        favRepository: mockFavRepo,
      );
      addTearDown(() => container.dispose());

      await container.read(favoritesControllerProvider.notifier).load();
      await container
          .read(favoritesControllerProvider.notifier)
          .updateNote(id: 'fav-1', note: 'my note');

      expect(
        container.read(favoritesControllerProvider).favorites.first.note,
        'my note',
      );
    });
  });

  group('unauthenticated paths', () {
    test('load returns to initial state when userId is null', () async {
      when(() => mockAuthRepo.userId).thenReturn(null);

      final container = makeContainer(
        authRepository: mockAuthRepo,
        favRepository: mockFavRepo,
      );
      addTearDown(() => container.dispose());

      await container.read(favoritesControllerProvider.notifier).load();

      final state = container.read(favoritesControllerProvider);
      expect(state.favorites, isEmpty);
      expect(state.error, isNull);
      // Critically: the repository must NOT be hit for anonymous users —
      // otherwise we'd leak Supabase queries on every cold start.
      verifyNever(() => mockFavRepo.fetchAll(userId: any(named: 'userId')));
    });

    test('toggle is a no-op when userId is null', () async {
      when(() => mockAuthRepo.userId).thenReturn(null);

      final container = makeContainer(
        authRepository: mockAuthRepo,
        favRepository: mockFavRepo,
      );
      addTearDown(() => container.dispose());

      await container
          .read(favoritesControllerProvider.notifier)
          .toggle(buildingId: 'BLD', buildingName: 'Library');

      verifyNever(
        () => mockFavRepo.findFavoriteId(
          userId: any(named: 'userId'),
          buildingId: any(named: 'buildingId'),
        ),
      );
    });
  });

  group('updateNote edge cases', () {
    test('failure leaves prior favorite untouched in state', () async {
      when(() => mockAuthRepo.userId).thenReturn('user-1');
      when(
        () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
      ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));
      when(
        () => mockFavRepo.updateNote(
          id: any(named: 'id'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => FavoritesResult.failure('Network down.'));

      final container = makeContainer(
        authRepository: mockAuthRepo,
        favRepository: mockFavRepo,
      );
      addTearDown(() => container.dispose());

      await container.read(favoritesControllerProvider.notifier).load();
      final beforeNote = container
          .read(favoritesControllerProvider)
          .favorites
          .first
          .note;
      await container
          .read(favoritesControllerProvider.notifier)
          .updateNote(id: 'fav-1', note: 'attempted note');

      final afterNote = container
          .read(favoritesControllerProvider)
          .favorites
          .first
          .note;
      // The state should NOT be optimistically updated on failure —
      // the note remains whatever it was before the failed call.
      expect(afterNote, beforeNote);
    });
  });

  group('isFavorited', () {
    test('returns true for favorited building', () async {
      when(() => mockAuthRepo.userId).thenReturn('user-1');
      when(
        () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
      ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));

      final container = makeContainer(
        authRepository: mockAuthRepo,
        favRepository: mockFavRepo,
      );
      addTearDown(() => container.dispose());

      await container.read(favoritesControllerProvider.notifier).load();

      expect(
        container.read(favoritesControllerProvider.notifier).isFavorited('BLD'),
        isTrue,
      );
    });
  });
}
