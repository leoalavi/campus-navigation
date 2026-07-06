import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mq_journey/core/config/env_config.dart';
import 'package:mq_journey/core/logging/app_logger.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/features/transit/domain/entities/metro_departure.dart';
import 'package:mq_journey/features/transit/domain/entities/transit_stop.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final tfnswMetroProvider = StreamProvider.autoDispose<List<MetroDeparture>>((
  ref,
) async* {
  final preferences = await ref.watch(settingsControllerProvider.future);
  if (!ref.mounted) {
    return;
  }
  if (preferences.commuteMode == 'none') {
    yield const [];
    return;
  }

  final locationSource = ref.read(locationSourceProvider);
  while (true) {
    final location = await locationSource.getCurrentLocation();
    if (!ref.mounted) {
      return;
    }

    final departures = await _fetchDepartures(
      favoriteDirection: preferences.favoriteDirection,
      favoriteRoute: preferences.favoriteRoute,
      favoriteStopId: preferences.favoriteStopId,
      mode: preferences.commuteMode,
      latitude: location?.latitude,
      longitude: location?.longitude,
    );
    if (!ref.mounted) {
      return;
    }

    yield departures;
    await Future<void>.delayed(const Duration(seconds: 20));
    if (!ref.mounted) {
      return;
    }
  }
});

typedef TfnswStopSearchQuery = ({String mode, String query});

final tfnswStopSearchProvider = FutureProvider.autoDispose
    .family<List<TransitStop>, TfnswStopSearchQuery>((ref, search) {
      return _searchStops(mode: search.mode, query: search.query);
    });

/// Auth headers for the tfnsw-proxy edge function.
///
/// The function is deployed with `verify_jwt: true`, so the Supabase gateway
/// requires an `Authorization: Bearer <JWT>` header on every request — the
/// `apikey` header alone is rejected with 401 before the function runs.
/// This app has no user sign-in (auth was removed), so there is never a
/// session token; the anon key (itself a JWT) is the correct fallback —
/// the same thing supabase-js sends for unauthenticated calls.
Map<String, String> _tfnswAuthHeaders() {
  final token =
      Supabase.instance.client.auth.currentSession?.accessToken ??
      EnvConfig.supabaseAnonKey;
  return {
    'Authorization': 'Bearer $token',
    'apikey': EnvConfig.supabaseAnonKey,
  };
}

Future<List<MetroDeparture>> _fetchDepartures({
  required String favoriteDirection,
  required String favoriteRoute,
  required String favoriteStopId,
  required String mode,
  required double? latitude,
  required double? longitude,
}) async {
  try {
    final query = <String, String>{
      'mode': mode,
      if (favoriteDirection.trim().isNotEmpty)
        'direction': favoriteDirection.trim(),
      if (favoriteRoute.trim().isNotEmpty) 'route': favoriteRoute.trim(),
      if (favoriteStopId.trim().isNotEmpty) 'stopId': favoriteStopId.trim(),
      if (latitude != null) 'lat': latitude.toString(),
      if (longitude != null) 'lng': longitude.toString(),
    };
    final response = await http.get(
      Uri.parse(
        '${EnvConfig.supabaseUrl}/functions/v1/tfnsw-proxy',
      ).replace(queryParameters: query),
      headers: _tfnswAuthHeaders(),
    );

    if (response.statusCode != 200) {
      return const [];
    }

    final dynamic decoded = jsonDecode(response.body);
    final list = (decoded as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MetroDeparture.fromJson)
        .toList();
    return list;
  } catch (error, stackTrace) {
    AppLogger.warning('TfNSW proxy request failed', error, stackTrace);
    return const [];
  }
}

Future<List<TransitStop>> _searchStops({
  required String mode,
  required String query,
}) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) {
    return const [];
  }

  try {
    final response = await http.get(
      Uri.parse('${EnvConfig.supabaseUrl}/functions/v1/tfnsw-proxy').replace(
        queryParameters: {'action': 'stop-search', 'mode': mode, 'q': trimmed},
      ),
      headers: _tfnswAuthHeaders(),
    );

    if (response.statusCode != 200) {
      return const [];
    }

    final dynamic decoded = jsonDecode(response.body);
    final list = (decoded as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(TransitStop.fromJson)
        .where((stop) => stop.id.isNotEmpty && stop.name.isNotEmpty)
        .toList();
    return dedupeTransitStops(list);
  } catch (error, stackTrace) {
    AppLogger.warning('TfNSW stop search failed', error, stackTrace);
    return const [];
  }
}

/// TfNSW returns the parent station and each platform stop as separate
/// records (e.g. `2155384` Tallawong Station and `G276288` Tallawong
/// Station, Implexa Pde). For a "preferred stop" UX, the user thinks
/// of those as the same place. Collapse by the part before the first
/// comma (case-insensitive, trimmed) and keep the entry with the
/// shortest name — i.e. the parent-station / cleanest version.
///
/// Exposed (without the leading underscore) so unit tests can pin
/// the dedup contract without going through the network layer.
List<TransitStop> dedupeTransitStops(List<TransitStop> stops) {
  final byKey = <String, TransitStop>{};
  for (final stop in stops) {
    final key = stop.name.split(',').first.trim().toLowerCase();
    if (key.isEmpty) {
      continue;
    }
    final existing = byKey[key];
    if (existing == null || stop.name.length < existing.name.length) {
      byKey[key] = stop;
    }
  }
  return byKey.values.toList(growable: false);
}
