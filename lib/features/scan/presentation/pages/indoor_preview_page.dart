import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/immersive_viewer_active_provider.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/scan/presentation/widgets/indoor_tour_view.dart';
import 'package:mq_journey/shared/widgets/glass_app_bar.dart';

class IndoorPreviewPage extends ConsumerStatefulWidget {
  const IndoorPreviewPage({super.key, required this.buildingId, this.onBack});
  final String buildingId;

  /// When provided, the app bar shows a leading back button that calls this
  /// instead of relying on the navigation stack. Used when the page is
  /// embedded (not pushed) — e.g. the AR building picker in the Map tab swaps
  /// itself for this page, so there is nothing to pop; [onBack] returns to
  /// the picker. When null the app bar uses its default behaviour (an
  /// automatic back button only when the route can be popped).
  final VoidCallback? onBack;

  @override
  ConsumerState<IndoorPreviewPage> createState() => _IndoorPreviewPageState();
}

class _IndoorPreviewPageState extends ConsumerState<IndoorPreviewPage> {
  // Captured in initState so dispose can clear the flag without touching `ref`
  // (using `ref` after unmount is unsafe). The notifier itself is app-scoped
  // and stable.
  ImmersiveViewerActiveNotifier? _immersive;

  @override
  void initState() {
    super.initState();
    _immersive = ref.read(immersiveViewerActiveProvider.notifier);
    // While this platform-view panorama is on screen, tell the shell to frost
    // its tab-bar glass — a refraction shader can't sample the webview behind.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _immersive?.setActive(true);
    });
  }

  @override
  void dispose() {
    _immersive?.setActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final manifestAsync = ref.watch(indoorManifestProvider(widget.buildingId));

    // Prefer the building's friendly name from the Open Day trail (e.g.
    // "10 Hadenfeld Avenue") over the raw slug title ("hadenfeld-10 Indoor").
    // Falls back to the slug while the trail is still loading or when the
    // building isn't on the trail (e.g. a legacy map-code deep link).
    final trail = ref.watch(trailManifestProvider).value;
    String? friendlyName;
    if (trail != null) {
      for (final loc in trail.locations) {
        if (loc.buildingId == widget.buildingId ||
            loc.locationId == widget.buildingId) {
          friendlyName = loc.title;
          break;
        }
      }
    }
    final title = friendlyName ?? '${widget.buildingId} Indoor';

    return Scaffold(
      // The 360° panorama runs behind the glass island title bar.
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        // Platform-view body: frost, not shader (a shader can't sample it).
        allowShader: false,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: AppLocalizations.of(context)!.back,
                onPressed: widget.onBack,
              )
            : null,
        title: Text(title),
      ),
      body: manifestAsync.when(
        data: (manifest) {
          if (manifest == null || manifest.isEmpty) {
            return Center(child: Text(l10n.indoorNoPreview));
          }
          // Shown inside the shell (the /map → indoor route), so the floating
          // tab-bar island is present — reserve clearance for it.
          return IndoorTourView(
            manifest: manifest,
            reserveBottomForTabBar: true,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.indoorPreviewLoadError(e.toString()))),
      ),
    );
  }
}
