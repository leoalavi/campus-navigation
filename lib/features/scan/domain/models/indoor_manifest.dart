import 'dart:convert';
import 'package:flutter/foundation.dart';

@immutable
class NodeNeighbour {
  final String id;
  final double bearing;
  final String? label;

  const NodeNeighbour({required this.id, required this.bearing, this.label});
}

@immutable
class IndoorNode {
  final String id;
  final String image;
  final String description;
  final List<NodeNeighbour> neighbours;

  const IndoorNode({
    required this.id,
    required this.image,
    required this.description,
    this.neighbours = const [],
  });
}

@immutable
class IndoorManifest {
  final List<IndoorNode> nodes;

  const IndoorManifest({required this.nodes});

  bool get isEmpty => nodes.isEmpty;

  factory IndoorManifest.fromJson(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final nodeList = (json['nodes'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          return IndoorNode(
            id: m['id'] as String,
            image: m['image'] as String,
            description: (m['description'] as String?) ?? '',
            neighbours: ((m['neighbours'] as List?) ?? [])
                .map((n) {
                  final nm = n as Map<String, dynamic>;
                  // Manifest assets use `targetId`/`heading`; older fixtures
                  // use `id`/`bearing`. Accept both schemas.
                  return NodeNeighbour(
                    id: (nm['targetId'] ?? nm['id']) as String,
                    bearing: ((nm['heading'] ?? nm['bearing']) as num)
                        .toDouble(),
                    label: nm['label'] as String?,
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    return IndoorManifest(nodes: nodeList);
  }

  Map<String, dynamic> buildPannellumConfig({
    required String assetBaseUrl,
    String? firstSceneId,
  }) {
    final scenes = <String, dynamic>{};
    for (final node in nodes) {
      scenes[node.id] = {
        'type': 'equirectangular',
        'panorama': '$assetBaseUrl/${node.image}',
        'hotSpots': [
          for (final n in node.neighbours)
            {
              'type': 'scene',
              'sceneId': n.id,
              'yaw': n.bearing,
              'text': n.label ?? 'Go',
            },
        ],
      };
    }
    final hasRequested =
        firstSceneId != null && nodes.any((n) => n.id == firstSceneId);
    return {
      'default': {
        if (nodes.isNotEmpty)
          'firstScene': hasRequested ? firstSceneId : nodes.first.id,
        'sceneFadeDuration': 600,
      },
      'scenes': scenes,
    };
  }
}
