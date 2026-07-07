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
      // Hot spots must carry a pitch or Pannellum positions them at NaN.
      expect(hotspots.first['pitch'], 0);
    });

    test('scene opens facing its first hotspot when no preview is set', () {
      final m = IndoorManifest.fromJson(json);
      final config = m.buildPannellumConfig(assetBaseUrl: '/indoor');
      // lobby's first (only) hotspot sits at yaw 90 — the initial camera
      // must face it so "where to go next" is immediately visible.
      expect(config['scenes']['lobby']['yaw'], 90);
      expect(config['scenes']['stairs']['yaw'], -90);
    });

    test('previewHeading/previewPitch override the initial view', () {
      const withPreview = '''{
        "nodes": [
          {
            "id": "desk",
            "image": "x/desk.jpg",
            "description": "Desk",
            "previewHeading": 45,
            "previewPitch": -10,
            "neighbours": [{"id": "lobby", "bearing": 180}]
          }
        ]
      }''';
      final m = IndoorManifest.fromJson(withPreview);
      final config = m.buildPannellumConfig(assetBaseUrl: '/indoor');
      expect(config['scenes']['desk']['yaw'], 45);
      expect(config['scenes']['desk']['pitch'], -10);
    });

    test('buildPannellumConfig enables autoLoad so the panorama renders', () {
      final m = IndoorManifest.fromJson(json);
      final config = m.buildPannellumConfig(assetBaseUrl: '/indoor');
      expect(config['default']['autoLoad'], isTrue);
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

    test(
      'buildPannellumConfig falls back to first node for unknown firstSceneId',
      () {
        final m = IndoorManifest.fromJson(json);
        final cfg = m.buildPannellumConfig(
          assetBaseUrl: '/data',
          firstSceneId: 'missing',
        );
        expect((cfg['default'] as Map)['firstScene'], 'lobby');
      },
    );
  });
}
