import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
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
  bool _serverReady = kIsWeb;
  bool _serverFailed = false;

  @override
  void initState() {
    super.initState();
    // On web there is no localhost server (flutter_inappwebview provides no
    // web implementation of InAppLocalhostServer — start() throws) and none
    // is needed: the Flutter web server already serves every bundled asset
    // same-origin under `assets/<asset-key>`, so the viewer iframe and the
    // panorama images are addressed relative to the app's own origin.
    if (!kIsWeb) _startServer();
  }

  Future<void> _startServer() async {
    try {
      await _ensureIndoorServer();
      if (mounted) setState(() => _serverReady = true);
    } catch (_) {
      // Surface a real error state — an eternal spinner is untestable and
      // reads as a hang.
      if (mounted) setState(() => _serverFailed = true);
    }
  }

  /// Base URL the viewer page + panorama images are served from.
  ///
  /// Web: same-origin asset URLs resolved against the page base href, so the
  /// iframe is same-origin and `evaluateJavascript` (contentWindow eval) is
  /// permitted. The double `assets/assets` is correct: Flutter web serves
  /// every bundled asset under the `assets/` URL prefix keyed by its full
  /// asset key, and our keys themselves start with `assets/` (e.g. asset
  /// `assets/web/indoor_viewer.html` → URL `assets/assets/web/...`).
  /// Other platforms: the localhost asset server, whose document root is
  /// already the `assets/` directory.
  String get _viewerBase =>
      kIsWeb ? Uri.base.resolve('assets/assets').toString() : _indoorServerBase;

  InAppWebViewSettings get _settings => InAppWebViewSettings(
    javaScriptEnabled: true,
    transparentBackground: true,
    mediaPlaybackRequiresUserGesture: true,
    // The iframe only ever loads our own bundled viewer page.
    iframeAllow: 'fullscreen',
  );

  @override
  Widget build(BuildContext context) {
    if (_serverFailed) {
      return Center(child: Text(AppLocalizations.of(context)!.cardNoArPreview));
    }
    if (!_serverReady) {
      return const Center(child: CircularProgressIndicator());
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('$_viewerBase/web/indoor_viewer.html'),
      ),
      initialSettings: _settings,
      onLoadStop: (controller, _) async {
        // Manifest `image` values already include the `indoor/` segment
        // (e.g. `indoor/c3a_entrance.jpg`), which maps to
        // `assets/data/indoor/...`, so the base is `<viewerBase>/data`.
        final config = widget.manifest.buildPannellumConfig(
          assetBaseUrl: '$_viewerBase/data',
          firstSceneId: widget.firstSceneId,
        );
        await controller.evaluateJavascript(
          source: 'loadTour(${jsonEncode(config)});',
        );
      },
    );
  }
}
