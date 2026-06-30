import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';
import 'package:mq_journey/features/scan/presentation/widgets/indoor_webview.dart';
import 'package:mq_journey/features/scan/presentation/widgets/indoor_stop_list.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';

/// Pure scene resolution (spec refinement #3): a valid stop scene wins;
/// otherwise fall back to the entrance scene; otherwise null (Pannellum uses
/// nodes.first).
String? resolveArFirstScene({
  required IndoorManifest manifest,
  required String? stopSceneId,
  required String? entranceSceneId,
}) {
  bool has(String? id) => id != null && manifest.nodes.any((n) => n.id == id);
  if (has(stopSceneId)) return stopSceneId;
  if (has(entranceSceneId)) return entranceSceneId;
  return null;
}

class LocationArPage extends ConsumerWidget {
  const LocationArPage({super.key, required this.locationId, this.stopId});
  final String locationId;
  final String? stopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final trailAsync = ref.watch(trailManifestProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cardArPreviewTitle)),
      body: trailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load AR: $e')),
        data: (trail) {
          final loc = trail.byId(locationId);
          final buildingId = loc?.buildingId;
          if (loc == null || buildingId == null) {
            return Center(child: Text(l10n.cardNoArPreview));
          }
          final manifestAsync = ref.watch(indoorManifestProvider(buildingId));
          return manifestAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load AR: $e')),
            data: (manifest) {
              if (manifest == null || manifest.isEmpty) {
                return Center(child: Text(l10n.cardNoArPreview));
              }
              String? stopScene;
              for (final s in loc.stops) {
                if (s.stopId == stopId) {
                  stopScene = s.arSceneId;
                  break;
                }
              }
              final firstScene = resolveArFirstScene(
                manifest: manifest,
                stopSceneId: stopScene,
                entranceSceneId: loc.arSceneId,
              );
              return Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: IndoorWebView(
                      manifest: manifest,
                      firstSceneId: firstScene,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(flex: 2, child: IndoorStopList(manifest: manifest)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
