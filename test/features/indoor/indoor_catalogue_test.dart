import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/features/indoor/data/repositories/indoor_repository.dart';

/// Integrity guards for the migrated 360° catalogue.
///
/// These assert the *outcome* of the MQ Journey / Astronomy Open Night
/// migration rather than any one file, so a future edit that reintroduces an
/// event slug, a duplicate location or a dangling panorama fails loudly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<Map<String, dynamic>>> buildings() async {
    final raw = await rootBundle.loadString('assets/data/buildings.json');
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  test('every tour belongs to a building the rest of the app knows', () async {
    final ids = {for (final b in await buildings()) b['id'] as String};
    for (final tourId in await IndoorRepository().tourIds()) {
      expect(
        ids,
        contains(tourId),
        reason: 'tour $tourId has no building; map/search could not reach it',
      );
    }
  });

  test('every panorama referenced by a manifest is bundled', () async {
    final repo = IndoorRepository();
    for (final id in await repo.tourIds()) {
      final manifest = await repo.load(id);
      for (final node in manifest!.nodes) {
        expect(
          node.image,
          startsWith('indoor/$id'),
          reason: '${node.id} in $id is not keyed to its building',
        );
        await expectLater(
          rootBundle.load('assets/data/${node.image}'),
          completes,
          reason: 'missing panorama ${node.image}',
        );
      }
    }
  });

  test('no Astronomy Open Night event content leaked in', () async {
    final repo = IndoorRepository();
    final haystack = StringBuffer();
    for (final id in await repo.tourIds()) {
      haystack.write(
        await rootBundle.loadString('assets/data/indoor/$id.json'),
      );
    }
    final text = haystack.toString().toLowerCase();
    for (final banned in const [
      'astronomy',
      'open night',
      'solar system walk',
      'passport',
      'stamp',
      'telescope park',
      'aon',
    ]) {
      expect(text, isNot(contains(banned)), reason: 'event term "$banned"');
    }
  });

  test('buildings.json has no duplicate ids or Open Day venue stubs', () async {
    final all = await buildings();
    final ids = all.map((b) => b['id'] as String).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate building id');
    for (final b in all) {
      expect(
        (b['description'] as String?) ?? '',
        isNot(contains('Open Day venue')),
        reason: '${b['id']} is an event stub',
      );
    }
  });
}
