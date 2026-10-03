import 'package:flutter/services.dart' show rootBundle;
import 'package:campus_navigation/features/scan/domain/models/trail_manifest.dart';

class TrailRepository {
  TrailManifest? _cached;

  Future<TrailManifest> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString('assets/data/open_day_trail.json');
    _cached = TrailManifest.fromJson(raw);
    return _cached!;
  }
}
