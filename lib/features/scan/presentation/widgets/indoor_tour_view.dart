import 'package:flutter/material.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';
import 'package:mq_journey/features/scan/presentation/widgets/indoor_stop_list.dart';
import 'package:mq_journey/features/scan/presentation/widgets/indoor_webview.dart';

/// Keeps the panorama and its scene list on one shared scene selection.
///
/// List taps switch the existing Pannellum viewer in place. Hotspot-driven
/// scene changes flow back from the JavaScript bridge and update the selected
/// row without rebuilding the surrounding page.
class IndoorTourView extends StatefulWidget {
  const IndoorTourView({super.key, required this.manifest, this.firstSceneId});

  final IndoorManifest manifest;
  final String? firstSceneId;

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
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: IndoorWebView(
            manifest: widget.manifest,
            firstSceneId: _selectedSceneId,
            sceneId: _selectedSceneId,
            onSceneChanged: _selectScene,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: IndoorStopList(
            manifest: widget.manifest,
            selectedSceneId: _selectedSceneId,
            onSceneSelected: _selectScene,
          ),
        ),
      ],
    );
  }
}
