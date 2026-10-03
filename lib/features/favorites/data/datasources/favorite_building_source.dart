import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mq_navigation/features/favorites/domain/entities/favorite_building.dart';

class FavoriteBuildingSource {
  FavoriteBuildingSource({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  static const _table = 'favorite_buildings';

  Future<List<FavoriteBuilding>> fetchAll({required String userId}) async {
    final data = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List<dynamic>)
        .map((row) => FavoriteBuilding.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<FavoriteBuilding> add({
    required String userId,
    required String buildingId,
    required String buildingName,
    String? note,
  }) async {
    final data = await _client
        .from(_table)
        .insert({
          'user_id': userId,
          'building_id': buildingId,
          'building_name': buildingName,
          'note': note,
        })
        .select()
        .single();
    return FavoriteBuilding.fromJson(data);
  }

  Future<void> remove(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  Future<FavoriteBuilding> updateNote({
    required String id,
    required String note,
  }) async {
    final data = await _client
        .from(_table)
        .update({'note': note})
        .eq('id', id)
        .select()
        .single();
    return FavoriteBuilding.fromJson(data);
  }

  Future<bool> isFavorited({
    required String userId,
    required String buildingId,
  }) async {
    final data = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('building_id', buildingId)
        .maybeSingle();
    return data != null;
  }

  Future<String?> findId({
    required String userId,
    required String buildingId,
  }) async {
    final data = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('building_id', buildingId)
        .maybeSingle();
    return data?['id'] as String?;
  }
}
