import 'package:flutter/material.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';
import 'package:mq_journey/features/scan/presentation/widgets/indoor_webview.dart';
import 'package:mq_journey/features/scan/presentation/widgets/scene_rail.dart';

/// Builds the panorama viewer for a scene. Injectable so widget tests can
/// substitute a fake and never build the real `InAppWebView` platform view
/// (which depends on a localhost asset server that isn't available in tests).
typedef IndoorViewerBuilder =
    Widget Function({
      required IndoorManifest manifest,
      required String sceneId,
      required ValueChanged<String> onSceneChanged,
    });

Widget _defaultViewer({
  required IndoorManifest manifest,
  required String sceneId,
  required ValueChanged<String> onSceneChanged,
}) => IndoorWebView(
  manifest: manifest,
  firstSceneId: sceneId,
  sceneId: sceneId,
  onSceneChanged: onSceneChanged,
);

/// Immersive 360° tour: a full-bleed panorama viewer with a floating
/// [SceneRail] of scene chips. Both share one scene selection.
///
/// List/chip taps switch the existing Pannellum viewer in place. Hotspot-driven
/// scene changes flow back from the JavaScript bridge and update the selected
/// chip without rebuilding the surrounding page.
class IndoorTourView extends StatefulWidget {
  const IndoorTourView({
    super.key,
    required this.manifest,
    this.firstSceneId,
    this.viewerBuilder,
  });

  final IndoorManifest manifest;
  final String? firstSceneId;

  /// Injectable for tests (a fake replaces the platform-view webview).
  final IndoorViewerBuilder? viewerBuilder;

  @override
  State<IndoorTourView> createState() => _IndoorTourViewState();
}

class _IndoorTourViewState extends State<IndoorTourView> {
  late String _selectedSceneId;

  @override
  void initState() {
    super.initState();
    _selectedSceneId = _resolveInitialScene();
  }

  @override
  void didUpdateWidget(covariant IndoorTourView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.manifest.nodes.any((node) => node.id == _selectedSceneId)) {
      _selectedSceneId = _resolveInitialScene();
    }
  }

  String _resolveInitialScene() {
    final requested = widget.firstSceneId;
    if (requested != null &&
        widget.manifest.nodes.any((node) => node.id == requested)) {
      return requested;
    }
    return widget.manifest.nodes.first.id;
  }

  void _selectScene(String sceneId) {
    if (sceneId == _selectedSceneId ||
        !widget.manifest.nodes.any((node) => node.id == sceneId)) {
      return;
    }
    setState(() => _selectedSceneId = sceneId);
  }

  @override
  Widget build(BuildContext context) {
    final buildViewer = widget.viewerBuilder ?? _defaultViewer;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: buildViewer(
            manifest: widget.manifest,
            sceneId: _selectedSceneId,
            onSceneChanged: _selectScene,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SceneRail(
            manifest: widget.manifest,
            selectedSceneId: _selectedSceneId,
            onSceneSelected: _selectScene,
          ),
        ),
      ],
    );
  }
}
