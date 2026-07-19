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
  const IndoorWebView({
    super.key,
    required this.manifest,
    this.firstSceneId,
    this.sceneId,
    this.onSceneChanged,
  });
  final IndoorManifest manifest;

  /// Scene id Pannellum should open on first. When null (or not a known node)
  /// the viewer opens the manifest's first node.
  final String? firstSceneId;

  /// Scene the existing viewer should switch to after initial load.
  final String? sceneId;

  /// Reports scene changes made inside Pannellum, including hotspot taps.
  final ValueChanged<String>? onSceneChanged;

  @override
  State<IndoorWebView> createState() => _IndoorWebViewState();
}

class _IndoorWebViewState extends State<IndoorWebView> {
  bool _serverReady = kIsWeb;
  bool _serverFailed = false;
  InAppWebViewController? _webViewController;
  String? _currentSceneId;
  bool _tourLoaded = false;

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

  @override
  void didUpdateWidget(covariant IndoorWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sceneId != oldWidget.sceneId) {
      _loadScene(widget.sceneId);
    }
  }

  Future<void> _loadScene(String? sceneId) async {
    final controller = _webViewController;
    if (!_tourLoaded ||
        controller == null ||
        sceneId == null ||
        sceneId == _currentSceneId ||
        !widget.manifest.nodes.any((node) => node.id == sceneId)) {
      return;
    }
    _currentSceneId = sceneId;
    await controller.evaluateJavascript(
      source: 'selectScene(${jsonEncode(sceneId)});',
    );
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
    // Enforce the navigation allowlist in [_shouldOverrideUrlLoading].
    useShouldOverrideUrlLoading: true,
    // The iframe only ever loads our own bundled viewer page.
    iframeAllow: 'fullscreen',
  );

  /// Defence-in-depth: the bundled viewer never navigates away from itself, so
  /// cancel any top-level navigation that isn't the localhost asset origin (or
  /// `about:blank`). Stops a crafted panorama/config from driving the WebView
  /// to a remote/phishing page. Sub-resources (JS/CSS/images) are governed by
  /// the page CSP, not this hook.
  Future<NavigationActionPolicy> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final url = action.request.url;
    if (url == null) return NavigationActionPolicy.CANCEL;
    final scheme = url.scheme.toLowerCase();
    if (scheme == 'about') return NavigationActionPolicy.ALLOW;
    final isLocalViewer =
        scheme == 'http' &&
        url.host == 'localhost' &&
        url.port == _indoorServerPort;
    return isLocalViewer
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

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
      shouldOverrideUrlLoading: kIsWeb ? null : _shouldOverrideUrlLoading,
      onWebViewCreated: (controller) {
        _webViewController = controller;
        controller.addJavaScriptHandler(
          handlerName: 'indoorSceneChanged',
          callback: (arguments) {
            if (arguments.isEmpty || arguments.first is! String) return null;
            final sceneId = arguments.first as String;
            if (!widget.manifest.nodes.any((node) => node.id == sceneId)) {
              return null;
            }
            _currentSceneId = sceneId;
            widget.onSceneChanged?.call(sceneId);
            return null;
          },
        );
      },
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
        _tourLoaded = true;
        _currentSceneId = widget.sceneId ?? widget.firstSceneId;
        await _loadScene(widget.sceneId);
      },
    );
  }
}
