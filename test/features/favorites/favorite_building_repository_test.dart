import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_navigation/features/favorites/data/datasources/favorite_building_source.dart';
import 'package:mq_navigation/features/favorites/data/repositories/favorite_building_repository.dart';
import 'package:mq_navigation/features/favorites/domain/entities/favorite_building.dart';

class MockFavoriteBuildingSource extends Mock
    implements FavoriteBuildingSource {}

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

void main() {
  late MockFavoriteBuildingSource mockSource;
  late FavoriteBuildingRepository repository;

  setUp(() {
    mockSource = MockFavoriteBuildingSource();
    repository = FavoriteBuildingRepository(source: mockSource);
  });

  group('fetchAll', () {
    test('returns list on success', () async {
      when(
        () => mockSource.fetchAll(userId: any(named: 'userId')),
      ).thenAnswer((_) async => [_sampleFav]);

      final result = await repository.fetchAll(userId: 'user-1');

      expect(result.success, isTrue);
      expect(result.data, hasLength(1));
      expect(result.data!.first.buildingId, 'BLD');
    });

    test('returns failure on error', () async {
      when(
        () => mockSource.fetchAll(userId: any(named: 'userId')),
      ).thenThrow(Exception('network error'));

      final result = await repository.fetchAll(userId: 'user-1');

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });
  });

  group('add', () {
    test('returns favorite on success', () async {
      when(
        () => mockSource.add(
          userId: any(named: 'userId'),
          buildingId: any(named: 'buildingId'),
          buildingName: any(named: 'buildingName'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => _sampleFav);

      final result = await repository.add(
        userId: 'user-1',
        buildingId: 'BLD',
        buildingName: 'Test Building',
      );

      expect(result.success, isTrue);
      expect(result.data!.buildingId, 'BLD');
    });

    test('returns failure on error', () async {
      when(
        () => mockSource.add(
          userId: any(named: 'userId'),
          buildingId: any(named: 'buildingId'),
          buildingName: any(named: 'buildingName'),
          note: any(named: 'note'),
        ),
      ).thenThrow(Exception('db error'));

      final result = await repository.add(
        userId: 'user-1',
        buildingId: 'BLD',
        buildingName: 'Test Building',
      );

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });
  });

  group('remove', () {
    test('returns success on success', () async {
      when(() => mockSource.remove(any())).thenAnswer((_) async {});

      final result = await repository.remove('fav-1');

      expect(result.success, isTrue);
    });

    test('returns failure on error', () async {
      when(() => mockSource.remove(any())).thenThrow(Exception('db error'));

      final result = await repository.remove('fav-1');

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });
  });

  group('updateNote', () {
    test('returns updated favorite on success', () async {
      final updated = _sampleFav.copyWith(note: 'my note');
      when(
        () => mockSource.updateNote(
          id: any(named: 'id'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => updated);

      final result = await repository.updateNote(id: 'fav-1', note: 'my note');

      expect(result.success, isTrue);
      expect(result.data!.note, 'my note');
    });
  });

  group('isFavorited', () {
    test('returns true when favorited', () async {
      when(
        () => mockSource.isFavorited(
          userId: any(named: 'userId'),
          buildingId: any(named: 'buildingId'),
        ),
      ).thenAnswer((_) async => true);

      final result = await repository.isFavorited(
        userId: 'user-1',
        buildingId: 'BLD',
      );

      expect(result.success, isTrue);
      expect(result.data, isTrue);
    });

    test('returns false when not favorited', () async {
      when(
        () => mockSource.isFavorited(
          userId: any(named: 'userId'),
          buildingId: any(named: 'buildingId'),
        ),
      ).thenAnswer((_) async => false);

      final result = await repository.isFavorited(
        userId: 'user-1',
        buildingId: 'BLD',
      );

      expect(result.success, isTrue);
      expect(result.data, isFalse);
    });
  });

  group('findFavoriteId', () {
    test('returns id when found', () async {
      when(
        () => mockSource.findId(
          userId: any(named: 'userId'),
          buildingId: any(named: 'buildingId'),
        ),
      ).thenAnswer((_) async => 'fav-1');

      final result = await repository.findFavoriteId(
        userId: 'user-1',
        buildingId: 'BLD',
      );

      expect(result, 'fav-1');
    });

    test('returns null on error', () async {
      when(
        () => mockSource.findId(
          userId: any(named: 'userId'),
          buildingId: any(named: 'buildingId'),
        ),
      ).thenThrow(Exception('error'));

      final result = await repository.findFavoriteId(
        userId: 'user-1',
        buildingId: 'BLD',
      );

      expect(result, isNull);
    });
  });
}
