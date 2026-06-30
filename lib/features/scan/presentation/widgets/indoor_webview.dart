import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';

/// Serves the Flutter `assets/` directory over localhost so the Pannellum
/// viewer HTML can reference its sibling JS/CSS and the panorama images via
/// stable `http://` URLs. Loading the page with `initialFile` (a `file://`
/// asset URL) cannot resolve cross-directory references such as the panorama
/// images under `assets/data/indoor/`, so the localhost server is used instead
/// (the approach recommended by the flutter_inappwebview v6 docs).
const int _indoorServerPort = 8459;
const String _indoorServerBase = 'http://localhost:$_indoorServerPort';
final InAppLocalhostServer _indoorAssetServer = InAppLocalhostServer(
  documentRoot: 'assets',
  port: _indoorServerPort,
);
Future<void>? _indoorServerStart;

Future<void> _ensureIndoorServer() =>
    _indoorServerStart ??= _indoorAssetServer.start();

class IndoorWebView extends StatefulWidget {
  const IndoorWebView({super.key, required this.manifest, this.firstSceneId});
  final IndoorManifest manifest;

  /// Scene id Pannellum should open on first. When null (or not a known node)
  /// the viewer opens the manifest's first node.
  final String? firstSceneId;

  @override
  State<IndoorWebView> createState() => _IndoorWebViewState();
}

class _IndoorWebViewState extends State<IndoorWebView> {
  bool _serverReady = false;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    await _ensureIndoorServer();
    if (mounted) setState(() => _serverReady = true);
  }

  InAppWebViewSettings get _settings => InAppWebViewSettings(
    javaScriptEnabled: true,
    transparentBackground: true,
    mediaPlaybackRequiresUserGesture: true,
  );

  @override
  Widget build(BuildContext context) {
    if (!_serverReady) {
      return const Center(child: CircularProgressIndicator());
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('$_indoorServerBase/web/indoor_viewer.html'),
      ),
      initialSettings: _settings,
      onLoadStop: (controller, _) async {
        // Manifest `image` values already include the `indoor/` segment
        // (e.g. `indoor/c3a_entrance.jpg`), which maps to
        // `assets/data/indoor/...`, so the base is `/data`.
        final config = widget.manifest.buildPannellumConfig(
          assetBaseUrl: '$_indoorServerBase/data',
          firstSceneId: widget.firstSceneId,
        );
        await controller.evaluateJavascript(
          source: 'loadTour(${jsonEncode(config)});',
        );
      },
    );
  }
}
