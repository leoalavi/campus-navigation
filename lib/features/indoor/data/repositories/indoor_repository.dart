import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:mq_navigation/core/logging/app_logger.dart';
import 'package:mq_navigation/features/indoor/domain/models/indoor_manifest.dart';

/// Loads the bundled 360° tour manifests.
///
/// Manifests are keyed by the canonical building id used everywhere else in
/// the app (`17WW.json`, `1CC.json`, …), so the map, search, building detail
/// and this viewer all address a location by the same identifier and cannot
/// drift apart.
///
/// The ids are case-sensitive (`23WW`, not `23ww`) because they are asset
/// filenames — do NOT lowercase them.
class IndoorRepository {
  IndoorRepository();

  static const String _indexAsset = 'assets/data/indoor/index.json';

  Map<String, int>? _sceneCounts;

  /// Building ids that ship a tour, mapped to their scene count.
  ///
  /// Read from a generated index rather than probing the bundle, so asking
  /// "does this building have a tour?" costs one cached asset read instead of
  /// a failed load (and a spurious warning) per building. The counts let the
  /// UI label the affordance ("4 scenes · 360° tour") without parsing any
  /// manifest or decoding a single panorama.
  Future<Map<String, int>> sceneCounts() async {
    if (_sceneCounts != null) return _sceneCounts!;
    try {
      final raw = await rootBundle.loadString(_indexAsset);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final tours = (json['tours'] as Map<String, dynamic>?) ?? const {};
      return _sceneCounts = {
        for (final e in tours.entries)
          if (e.value is num) e.key: (e.value as num).toInt(),
      };
    } catch (e, s) {
      AppLogger.warning('Could not read indoor tour index', e, s);
      return _sceneCounts = const <String, int>{};
    }
  }

  Future<Set<String>> tourIds() async => (await sceneCounts()).keys.toSet();

  /// Scene count for [buildingId], or `null` when it ships no tour.
  Future<int?> sceneCount(String buildingId) async =>
      (await sceneCounts())[buildingId];

  Future<bool> hasTour(String buildingId) async =>
      (await sceneCounts()).containsKey(buildingId);

  /// Loads the manifest for [buildingId], or `null` when the building ships no
  /// tour (or its manifest cannot be parsed).
  Future<IndoorManifest?> load(String buildingId) async {
    if (!await hasTour(buildingId)) return null;
    try {
      final raw = await rootBundle.loadString(
        'assets/data/indoor/$buildingId.json',
      );
      return IndoorManifest.fromJson(raw);
    } catch (e, s) {
      AppLogger.warning('Could not load indoor manifest for $buildingId', e, s);
      return null;
    }
  }
}
