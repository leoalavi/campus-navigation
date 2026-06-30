import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';

void main() {
  group('IndoorManifest', () {
    const json = '''{
      "nodes": [
        {
          "id": "lobby",
          "image": "c3a/lobby.jpg",
          "description": "Main entrance",
          "neighbours": [{"id": "stairs", "bearing": 90, "label": "To stairs"}]
        },
        {
          "id": "stairs",
          "image": "c3a/stairs.jpg",
          "description": "Stairwell",
          "neighbours": [{"id": "lobby", "bearing": -90}]
        }
      ]
    }''';

    test('parses valid manifest', () {
      final m = IndoorManifest.fromJson(json);
      expect(m.nodes.length, 2);
      expect(m.nodes.first.id, 'lobby');
      expect(m.nodes.first.neighbours.first.label, 'To stairs');
    });

    test('buildPannellumConfig generates correct structure', () {
      final m = IndoorManifest.fromJson(json);
      final config = m.buildPannellumConfig(assetBaseUrl: '/indoor');
      expect(config['default']['firstScene'], 'lobby');
      expect(config['scenes']['lobby'], isNotNull);
      final hotspots = config['scenes']['lobby']['hotSpots'] as List;
      expect(hotspots.first['yaw'], 90);
    });

    test('isEmpty is true for empty manifest', () {
      final m = IndoorManifest.fromJson('{"nodes":[]}');
      expect(m.isEmpty, isTrue);
    });

    test('buildPannellumConfig handles empty manifest without crashing', () {
      final m = IndoorManifest.fromJson('{"nodes":[]}');
      final config = m.buildPannellumConfig(assetBaseUrl: '/indoor');
      expect(config['default']['firstScene'], isNull);
      expect(config['scenes'], isEmpty);
    });

    test('buildPannellumConfig honours a valid firstSceneId', () {
      final m = IndoorManifest.fromJson(json);
      final cfg = m.buildPannellumConfig(
        assetBaseUrl: '/data',
        firstSceneId: 'stairs',
      );
      expect((cfg['default'] as Map)['firstScene'], 'stairs');
    });

    test('buildPannellumConfig falls back to first node for unknown firstSceneId',
        () {
      final m = IndoorManifest.fromJson(json);
      final cfg = m.buildPannellumConfig(
        assetBaseUrl: '/data',
        firstSceneId: 'missing',
      );
      expect((cfg['default'] as Map)['firstScene'], 'lobby');
    });
  });
}
