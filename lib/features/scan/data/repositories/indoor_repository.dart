import 'package:flutter/services.dart' show rootBundle;
import 'package:mq_journey/core/logging/app_logger.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';

class IndoorRepository {
  /// Loads the indoor manifest for [buildingId], or `null` when no manifest
  /// asset exists for the building (or it cannot be parsed).
  ///
  /// The asset filenames are case-sensitive (e.g. `C3A.json`, `18WW.json`), so
  /// the building code is used verbatim — do NOT lowercase it.
  Future<IndoorManifest?> load(String buildingId) async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/indoor/$buildingId.json',
      );
      return IndoorManifest.fromJson(raw);
    } catch (e, s) {
      AppLogger.warning('No indoor manifest for $buildingId', e, s);
      return null;
    }
  }
}
