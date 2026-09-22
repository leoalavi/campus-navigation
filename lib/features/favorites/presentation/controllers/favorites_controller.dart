import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/features/favorites/data/datasources/favorite_building_source.dart';
import 'package:mq_navigation/features/favorites/data/repositories/favorite_building_repository.dart';
import 'package:mq_navigation/features/favorites/domain/entities/favorite_building.dart';

final favoriteBuildingSourceProvider = Provider<FavoriteBuildingSource>((ref) {
  return FavoriteBuildingSource();
});

final favoriteBuildingRepositoryProvider = Provider<FavoriteBuildingRepository>(
  (ref) {
    return FavoriteBuildingRepository(
      source: ref.watch(favoriteBuildingSourceProvider),
    );
  },
);

class FavoritesController extends Notifier<FavoritesState> {
  @override
  FavoritesState build() {
    ref.onDispose(() => _disposed = true);

    // Favourites live on the device, so they are available immediately - there
    // is no sign-in to wait for. Loaded off the first frame so every
    // FavoriteButton across the Map tab shows the right filled/unfilled state
    // without the Favourites page having to be opened first.
    Future.microtask(load);

    return FavoritesState.initial();
  }

  FavoriteBuildingRepository get _repository =>
      ref.read(favoriteBuildingRepositoryProvider);

  bool _disposed = false;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.fetchAll();
    if (_disposed) return;
    if (result.success) {
      state = FavoritesState(
        favorites: result.data!,
        favoritedBuildingIds: result.data!.map((f) => f.buildingId).toSet(),
        isLoading: false,
        error: null,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }

  Future<void> toggle({
    required String buildingId,
    required String buildingName,
  }) async {
    final existingId = await _repository.findFavoriteId(buildingId: buildingId);

    if (existingId != null) {
      await _repository.remove(existingId);
    } else {
      await _repository.add(buildingId: buildingId, buildingName: buildingName);
    }
    await load();
  }

  Future<void> remove(String id) async {
    await _repository.remove(id);
    await load();
  }

  Future<void> updateNote({required String id, required String note}) async {
    final result = await _repository.updateNote(id: id, note: note);
    if (_disposed) return;
    if (result.success) {
      final updated = result.data!;
      state = FavoritesState(
        favorites: state.favorites
            .map((f) => f.id == id ? updated : f)
            .toList(),
        favoritedBuildingIds: state.favoritedBuildingIds,
        isLoading: false,
        error: null,
      );
    }
  }

  Future<void> refresh() async {
    await load();
  }

  bool isFavorited(String buildingId) {
    return state.favoritedBuildingIds.contains(buildingId);
  }
}

final favoritesControllerProvider =
    NotifierProvider<FavoritesController, FavoritesState>(
      FavoritesController.new,
    );

class FavoritesState {
  const FavoritesState({
    this.favorites = const [],
    this.favoritedBuildingIds = const {},
    this.isLoading = false,
    this.error,
  });

  factory FavoritesState.initial() => const FavoritesState();

  final List<FavoriteBuilding> favorites;
  final Set<String> favoritedBuildingIds;
  final bool isLoading;
  final String? error;

  FavoritesState copyWith({
    List<FavoriteBuilding>? favorites,
    Set<String>? favoritedBuildingIds,
    bool? isLoading,
    String? error,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      favoritedBuildingIds: favoritedBuildingIds ?? this.favoritedBuildingIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
