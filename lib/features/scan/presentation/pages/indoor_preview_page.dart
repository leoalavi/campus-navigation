import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/scan/presentation/widgets/indoor_webview.dart';
import 'package:mq_journey/features/scan/presentation/widgets/indoor_stop_list.dart';

class IndoorPreviewPage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final manifestAsync = ref.watch(indoorManifestProvider(buildingId));

    // Prefer the building's friendly name from the Open Day trail (e.g.
    // "10 Hadenfeld Avenue") over the raw slug title ("hadenfeld-10 Indoor").
    // Falls back to the slug while the trail is still loading or when the
    // building isn't on the trail (e.g. a legacy map-code deep link).
    final trail = ref.watch(trailManifestProvider).value;
    String? friendlyName;
    if (trail != null) {
      for (final loc in trail.locations) {
        if (loc.buildingId == buildingId || loc.locationId == buildingId) {
          friendlyName = loc.title;
          break;
        }
      }
    }
    final title = friendlyName ?? '$buildingId Indoor';

    return Scaffold(
      appBar: AppBar(
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: AppLocalizations.of(context)!.back,
                onPressed: onBack,
              )
            : null,
        title: Text(title),
      ),
      body: manifestAsync.when(
        data: (manifest) {
          if (manifest == null || manifest.isEmpty) {
            return Center(child: Text(l10n.indoorNoPreview));
          }
          return Column(
            children: [
              Expanded(flex: 3, child: IndoorWebView(manifest: manifest)),
              const Divider(height: 1),
              Expanded(flex: 2, child: IndoorStopList(manifest: manifest)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.indoorPreviewLoadError(e.toString()))),
      ),
    );
  }
}
