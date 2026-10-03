import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:campus_navigation/app/router/active_shell_branch_index_provider.dart';
import 'package:campus_navigation/app/router/route_names.dart';
import 'package:campus_navigation/core/config/env_config.dart';
import 'package:campus_navigation/core/logging/app_logger.dart';
import 'package:campus_navigation/features/map/data/datasources/location_source.dart';
import 'package:campus_navigation/features/settings/presentation/controllers/settings_controller.dart';
import 'package:campus_navigation/features/transit/domain/entities/metro_departure.dart';
import 'package:campus_navigation/features/transit/domain/entities/transit_stop.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef TfnswDeparturesFetcher =
    Future<List<MetroDeparture>> Function({
      required String favoriteDirection,
      required String favoriteRoute,
      required String favoriteStopId,
      required String mode,
      required double? latitude,
      required double? longitude,
    });

final tfnswHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final tfnswAuthHeadersProvider = Provider<Map<String, String>>(
  (ref) => tfnswRequestHeaders(
    accessToken: Supabase.instance.client.auth.currentSession?.accessToken,
  ),
);

final tfnswRequestTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

final tfnswDeparturesFetcherProvider = Provider<TfnswDeparturesFetcher>((ref) {
  final client = ref.watch(tfnswHttpClientProvider);
  final headers = ref.watch(tfnswAuthHeadersProvider);
  final requestTimeout = ref.watch(tfnswRequestTimeoutProvider);
  return ({
    required favoriteDirection,
    required favoriteRoute,
    required favoriteStopId,
    required mode,
    required latitude,
    required longitude,
  }) => _fetchDepartures(
    client: client,
    headers: headers,
    requestTimeout: requestTimeout,
    favoriteDirection: favoriteDirection,
    favoriteRoute: favoriteRoute,
    favoriteStopId: favoriteStopId,
    mode: mode,
    latitude: latitude,
    longitude: longitude,
  );
});

final tfnswPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 20),
);

final tfnswMetroProvider = StreamProvider.autoDispose<List<MetroDeparture>>((
  ref,
) async* {
  if (ref.watch(activeShellBranchIndexProvider) != ShellBranchIndex.home) {
    yield const [];
    return;
  }

  final preferences = await ref.watch(settingsControllerProvider.future);
  if (!ref.mounted) {
    return;
  }
  if (preferences.commuteMode == 'none') {
    yield const [];
    return;
  }

  final locationSource = ref.read(locationSourceProvider);
  final fetchDepartures = ref.read(tfnswDeparturesFetcherProvider);
  final pollInterval = ref.read(tfnswPollIntervalProvider);
  while (true) {
    final location = await locationSource.getCurrentLocation();
    if (!ref.mounted) {
      return;
    }

    final departures = await fetchDepartures(
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
    await Future<void>.delayed(pollInterval);
    if (!ref.mounted) {
      return;
    }
  }
});

typedef TfnswStopSearchQuery = ({String mode, String query});

final tfnswStopSearchProvider = FutureProvider.autoDispose
    .family<List<TransitStop>, TfnswStopSearchQuery>((ref, search) {
      return _searchStops(
        client: ref.watch(tfnswHttpClientProvider),
        headers: ref.watch(tfnswAuthHeadersProvider),
        requestTimeout: ref.watch(tfnswRequestTimeoutProvider),
        mode: search.mode,
        query: search.query,
      );
    });

/// Edge Functions with JWT verification enabled still require an
/// `Authorization` header for an anonymous client. Campus Navigation has no
/// account flow, so the public anon JWT is the correct fallback token.
///
/// Keeping this in one helper prevents stop search and departures from
/// drifting apart again and makes the anonymous request contract testable.
Map<String, String> tfnswRequestHeaders({String? accessToken}) {
  final bearer = accessToken?.trim().isNotEmpty == true
      ? accessToken!.trim()
      : EnvConfig.supabaseAnonKey;
  return {
    'Authorization': 'Bearer $bearer',
    'apikey': EnvConfig.supabaseAnonKey,
  };
}

Future<List<MetroDeparture>> _fetchDepartures({
  required http.Client client,
  required Map<String, String> headers,
  required Duration requestTimeout,
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
    final response = await client
        .get(
          Uri.parse(
            '${EnvConfig.supabaseUrl}/functions/v1/tfnsw-proxy',
          ).replace(queryParameters: query),
          headers: headers,
        )
        .timeout(requestTimeout);

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
  required http.Client client,
  required Map<String, String> headers,
  required Duration requestTimeout,
  required String mode,
  required String query,
}) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) {
    return const [];
  }

  try {
    final response = await client
        .get(
          Uri.parse(
            '${EnvConfig.supabaseUrl}/functions/v1/tfnsw-proxy',
          ).replace(
            queryParameters: {
              'action': 'stop-search',
              'mode': mode,
              'q': trimmed,
            },
          ),
          headers: headers,
        )
        .timeout(requestTimeout);

    if (response.statusCode != 200) {
      throw StateError('TfNSW stop search failed (${response.statusCode})');
    }

    final dynamic decoded = jsonDecode(response.body);
    return parseTransitStops(decoded);
  } catch (error, stackTrace) {
    AppLogger.warning('TfNSW stop search failed', error, stackTrace);
    rethrow;
  }
}

/// Parses the proxy payload while preserving a distinction between a valid
/// empty result and a malformed/error response.
List<TransitStop> parseTransitStops(dynamic decoded) {
  if (decoded is! List<dynamic>) {
    throw const FormatException('TfNSW stop search response is not a list');
  }
  final stops = decoded
      .whereType<Map<String, dynamic>>()
      .map(TransitStop.fromJson)
      .where((stop) => stop.id.isNotEmpty && stop.name.isNotEmpty)
      .toList();
  return dedupeTransitStops(stops);
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
