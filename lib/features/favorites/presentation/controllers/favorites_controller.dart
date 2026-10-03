import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/core/network/session_guard.dart';
import 'package:mq_navigation/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mq_navigation/features/favorites/data/datasources/favorite_building_source.dart';
import 'package:mq_navigation/features/favorites/data/repositories/favorite_building_repository.dart';
import 'package:mq_navigation/features/favorites/domain/entities/favorite_building.dart';

final favoriteBuildingSourceProvider = Provider<FavoriteBuildingSource>((ref) {
  return FavoriteBuildingSource(client: Supabase.instance.client);
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

    // React to auth state changes so heart icons stay in sync without
    // requiring the Favourites page to open first.
    //   • Signed in  → load from Supabase so all FavoriteButton widgets
    //     across the Map tab immediately show correct filled/unfilled state.
    //   • Signed out → reset to empty so stale rows from the previous
    //     session are not shown to a new user on the same device.
    ref.listen(authControllerProvider, (previous, next) {
      if (next.isAuthenticated) {
        load();
      } else {
        state = FavoritesState.initial();
      }
    });

    // If already authenticated when this provider is first created
    // (e.g. app cold-started with a valid session), schedule an
    // immediate load so the first frame already has correct state.
    final isAuthenticated = ref.read(authControllerProvider).isAuthenticated;
    if (isAuthenticated) {
      Future.microtask(load);
    }

    return FavoritesState.initial();
  }

  FavoriteBuildingRepository get _repository =>
      ref.read(favoriteBuildingRepositoryProvider);

  String? get _userId => ref.read(authRepositoryProvider).userId;

  bool _disposed = false;

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) {
      state = FavoritesState.initial();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.fetchAll(userId: userId);
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
    if (!await ref.read(sessionGuardProvider)()) return;
    final userId = _userId;
    if (userId == null) return;

    final existingId = await _repository.findFavoriteId(
      userId: userId,
      buildingId: buildingId,
    );

    if (existingId != null) {
      await _repository.remove(existingId);
    } else {
      await _repository.add(
        userId: userId,
        buildingId: buildingId,
        buildingName: buildingName,
      );
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
