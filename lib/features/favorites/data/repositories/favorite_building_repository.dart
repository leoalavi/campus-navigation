import 'package:mq_navigation/features/favorites/data/datasources/favorite_building_source.dart';
import 'package:mq_navigation/features/favorites/domain/entities/favorite_building.dart';

class FavoriteBuildingRepository {
  FavoriteBuildingRepository({required FavoriteBuildingSource source})
    : _source = source;

  final FavoriteBuildingSource _source;

  Future<FavoritesResult<List<FavoriteBuilding>>> fetchAll({
    required String userId,
  }) async {
    try {
      final list = await _source.fetchAll(userId: userId);
      return FavoritesResult.success(list);
    } catch (e) {
      return FavoritesResult.failure('Could not load favourites.');
    }
  }

  Future<FavoritesResult<FavoriteBuilding>> add({
    required String userId,
    required String buildingId,
    required String buildingName,
    String? note,
  }) async {
    try {
      final fav = await _source.add(
        userId: userId,
        buildingId: buildingId,
        buildingName: buildingName,
        note: note,
      );
      return FavoritesResult.success(fav);
    } catch (e) {
      return FavoritesResult.failure('Could not save favourite.');
    }
  }

  Future<FavoritesResult<void>> remove(String id) async {
    try {
      await _source.remove(id);
      return FavoritesResult.success(null);
    } catch (e) {
      return FavoritesResult.failure('Could not remove favourite.');
    }
  }

  Future<FavoritesResult<FavoriteBuilding>> updateNote({
    required String id,
    required String note,
  }) async {
    try {
      final fav = await _source.updateNote(id: id, note: note);
      return FavoritesResult.success(fav);
    } catch (e) {
      return FavoritesResult.failure('Could not update note.');
    }
  }

  Future<FavoritesResult<bool>> isFavorited({
    required String userId,
    required String buildingId,
  }) async {
    try {
      final result = await _source.isFavorited(
        userId: userId,
        buildingId: buildingId,
      );
      return FavoritesResult.success(result);
    } catch (e) {
      return FavoritesResult.failure('Could not check favourite status.');
    }
  }

  Future<String?> findFavoriteId({
    required String userId,
    required String buildingId,
  }) async {
    try {
      return await _source.findId(userId: userId, buildingId: buildingId);
    } catch (_) {
      return null;
    }
  }
}

class FavoritesResult<T> {
  const FavoritesResult._({required this.success, this.error, this.data});

  final bool success;
  final String? error;
  final T? data;

  factory FavoritesResult.success(T data) =>
      FavoritesResult._(success: true, data: data);

  factory FavoritesResult.failure(String error) =>
      FavoritesResult._(success: false, error: error);
}
