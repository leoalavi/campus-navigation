import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';

class StampCatalogRepository {
  List<StampCatalogEntry>? _cached;

  Future<List<StampCatalogEntry>> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString(
      'assets/data/open_day_stamps_catalog.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final stamps = json['stamps'] as List<dynamic>;
    _cached = stamps
        .map((e) => StampCatalogEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return _cached!;
  }
}
