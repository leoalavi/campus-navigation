import 'dart:convert';
import 'package:flutter/foundation.dart';

@immutable
class NodeNeighbour {
  final String id;
  final double bearing;
  final String? label;

  /// Vertical placement of the hotspot in degrees (0 = horizon). Lets a
  /// manifest pin an arrow onto a door/stair rather than floating at eye
  /// level when the target sits below/above the camera line.
  final double pitch;

  const NodeNeighbour({
    required this.id,
    required this.bearing,
    this.label,
    this.pitch = 0,
  });
}

@immutable
class IndoorNode {
  final String id;
  final String image;
  final String description;
  final List<NodeNeighbour> neighbours;

  /// Initial camera heading/pitch for this scene (degrees, Pannellum yaw
  /// convention: 0 = panorama centre, positive = right). When absent the
  /// scene opens facing its first hotspot so the "where to next" affordance
  /// is immediately visible.
  final double? previewHeading;
  final double? previewPitch;

  const IndoorNode({
    required this.id,
    required this.image,
    required this.description,
    this.neighbours = const [],
    this.previewHeading,
    this.previewPitch,
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
            previewHeading: (m['previewHeading'] as num?)?.toDouble(),
            previewPitch: (m['previewPitch'] as num?)?.toDouble(),
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
                    pitch: (nm['pitch'] as num?)?.toDouble() ?? 0,
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
      // Open each scene facing its authored preview heading, or failing
      // that, its first hotspot — never a random default angle. A visitor
      // should land looking at "where to go next", not a blank wall.
      final initialYaw =
          node.previewHeading ??
          (node.neighbours.isNotEmpty ? node.neighbours.first.bearing : 0.0);
      scenes[node.id] = {
        'type': 'equirectangular',
        // Only ever resolve a panorama *inside* the bundled asset server. A
        // value with a URI scheme, an absolute/scheme-relative leading slash,
        // or a `..` traversal (e.g. `https://evil/beacon.jpg`, `//host/x`,
        // `../../secret`) would otherwise make the WebView fetch remote or
        // unintended content — blank it instead of building an off-origin URL.
        'panorama': _isSafeRelativeImagePath(node.image)
            ? '$assetBaseUrl/${node.image}'
            : '',
        'yaw': initialYaw,
        'pitch': node.previewPitch ?? 0,
        // 90° gives a natural, less fisheye-distorted framing than
        // Pannellum's 100° default; clamp zoom so users can't zoom out into
        // a warped "little planet" or in past the imagery's resolution.
        'hfov': 90,
        'minHfov': 55,
        'maxHfov': 110,
        // Phone-shot equirectangular panoramas have badly stitched, warped
        // zenith/nadir poles — clamp vertical look so users never end up
        // staring at the ugly seams above/below.
        'minPitch': -50,
        'maxPitch': 50,
        'hotSpots': [
          for (final n in node.neighbours)
            {
              'type': 'scene',
              'sceneId': n.id,
              'yaw': n.bearing,
              // Pannellum positions hot spots with `pitch * PI/180`; an
              // absent pitch becomes NaN and the marker never renders, so
              // it is always explicit (0 = horizon).
              'pitch': n.pitch,
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
        // Pannellum's `autoLoad` defaults to false, which shows a "Click to
        // Load" button instead of the panorama. In an embedded viewer we always
        // want the scene to render immediately.
        'autoLoad': true,
        'sceneFadeDuration': 600,
        // Hide Pannellum's built-in UI chrome — the zoom +/− buttons and the
        // fullscreen toggle in the top-left corner. They're not useful in the
        // embedded viewer (pinch/drag still work).
        'showControls': false,
      },
      'scenes': scenes,
    };
  }
}

/// Whether [path] is a safe, *relative* asset path that resolves inside the
/// bundled localhost asset server — no URI scheme (`http:`, `data:`,
/// `javascript:`…), no absolute or scheme-relative leading slash, and no `..`
/// traversal segment. Used to gate panorama image refs before they become a
/// WebView URL, so a hostile/remote value can never trigger an off-origin fetch.
bool _isSafeRelativeImagePath(String path) {
  if (path.isEmpty) return false;
  // Any URI scheme (letters/digits/+/-/., then a colon) — also catches `//host`
  // via the leading-slash check below.
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:').hasMatch(path)) return false;
  if (path.startsWith('/') || path.startsWith(r'\')) return false;
  final segments = path.split(RegExp(r'[/\\]'));
  if (segments.contains('..')) return false;
  return true;
}
