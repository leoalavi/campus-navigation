import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/core/logging/app_logger.dart';

/// Resolves an inbound deep-link building id to a canonical one.
///
/// Campus Navigation owns campus identity: sister apps (Syllabus Sync) send
/// whatever building id they already hold and this class maps it onto the
/// canonical id in `buildings.json`. Keeping the mapping here means partner
/// apps never have to mirror — and drift from — our building table.
///
/// Resolution order:
///   1. exact canonical id
///   2. case-insensitive canonical id (`17ww` → `17WW`)
///   3. the partner alias table (`1WW` → `AINS`)
///
/// A miss returns `null` so the caller can degrade honestly rather than
/// dropping the user on an arbitrary building.
class BuildingIdResolver {
  BuildingIdResolver({this.bundle});

  /// Injectable for tests; defaults to the app bundle.
  final Future<String> Function(String key)? bundle;

  Map<String, String>? _canonicalByUpper;
  Map<String, String>? _aliases;

  Future<String> _load(String key) => (bundle ?? rootBundle.loadString)(key);

  Future<void> _ensureLoaded() async {
    if (_canonicalByUpper != null) return;
    try {
      final raw = await _load('assets/data/buildings.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _canonicalByUpper = {
        for (final b in list)
          (b['id'] as String).toUpperCase(): b['id'] as String,
      };
    } catch (e, s) {
      AppLogger.warning('Could not load buildings for id resolution', e, s);
      _canonicalByUpper = const {};
    }
    try {
      final raw = await _load('assets/data/building_aliases.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final map = (json['aliases'] as Map<String, dynamic>?) ?? const {};
      _aliases = {
        for (final e in map.entries) e.key.toUpperCase(): e.value as String,
      };
    } catch (e, s) {
      AppLogger.warning('Could not load building aliases', e, s);
      _aliases = const {};
    }
  }

  /// The canonical id for [rawId], or `null` when it names nothing we know.
  Future<String?> resolve(String rawId) async {
    final id = rawId.trim();
    if (id.isEmpty) return null;
    await _ensureLoaded();
    final upper = id.toUpperCase();
    final direct = _canonicalByUpper![upper];
    if (direct != null) return direct;
    final aliased = _aliases![upper];
    // An alias must still name a real building; a stale entry resolves to
    // nothing rather than routing to a building that no longer exists.
    if (aliased != null) return _canonicalByUpper![aliased.toUpperCase()];
    return null;
  }
}

final buildingIdResolverProvider = Provider<BuildingIdResolver>(
  (ref) => BuildingIdResolver(),
);
