import 'package:flutter/services.dart' show rootBundle;
import 'package:campus_navigation/features/scan/domain/models/buildings_registry.dart';

class BuildingsRepository {
  BuildingsRegistry? _cached;

  Future<BuildingsRegistry> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString('assets/data/buildings.json');
    _cached = BuildingsRegistry.fromJson(raw);
    return _cached!;
  }
}
