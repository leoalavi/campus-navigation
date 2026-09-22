import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mq_navigation/features/favorites/domain/entities/favorite_building.dart';

/// On-device store for saved buildings.
///
/// Campus Navigation has no accounts, so favourites live on the device and
/// belong to whoever is holding it. Nothing here leaves the phone, which also
/// means saving a building works offline and needs no network round-trip.
class FavoriteBuildingSource {
  FavoriteBuildingSource({SharedPreferences? prefs}) : _injected = prefs;

  /// Injectable for tests; production resolves the shared instance lazily.
  final SharedPreferences? _injected;

  static const String _key = 'favorite_buildings_v1';

  Future<SharedPreferences> _prefs() async =>
      _injected ?? await SharedPreferences.getInstance();

  Future<List<FavoriteBuilding>> _readAll() async {
    final raw = (await _prefs()).getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    // A corrupt or half-written entry must not brick the Favourites tab —
    // treat it as "no favourites" rather than throwing on every read.
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => FavoriteBuilding.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeAll(List<FavoriteBuilding> items) async {
    final prefs = await _prefs();
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  /// Newest first, matching what the Favourites page expects.
  Future<List<FavoriteBuilding>> fetchAll() async {
    final all = await _readAll();
    final sorted = [...all]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Future<FavoriteBuilding> add({
    required String buildingId,
    required String buildingName,
    String? note,
  }) async {
    final all = await _readAll();
    final existing = all.where((f) => f.buildingId == buildingId).firstOrNull;
    // Saving an already-saved building is a no-op rather than a duplicate row,
    // so a double tap cannot leave two hearts pointing at one place.
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    final fav = FavoriteBuilding(
      id: '${now.microsecondsSinceEpoch}-$buildingId',
      buildingId: buildingId,
      buildingName: buildingName,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await _writeAll([...all, fav]);
    return fav;
  }

  Future<void> remove(String id) async {
    final all = await _readAll();
    await _writeAll(all.where((f) => f.id != id).toList(growable: false));
  }

  Future<FavoriteBuilding> updateNote({
    required String id,
    required String note,
  }) async {
    final all = await _readAll();
    final index = all.indexWhere((f) => f.id == id);
    if (index == -1) {
      throw StateError('No favourite with id $id');
    }
    final updated = all[index].copyWith(
      note: note,
      updatedAt: DateTime.now().toUtc(),
    );
    final next = [...all]..[index] = updated;
    await _writeAll(next);
    return updated;
  }

  Future<bool> isFavorited({required String buildingId}) async =>
      (await _readAll()).any((f) => f.buildingId == buildingId);

  Future<String?> findId({required String buildingId}) async =>
      (await _readAll()).where((f) => f.buildingId == buildingId).firstOrNull?.id;
}
