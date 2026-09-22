import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/features/indoor/presentation/widgets/indoor_tour_view.dart';
import 'package:mq_navigation/features/indoor/providers/indoor_providers.dart';
import 'package:mq_navigation/features/map/data/datasources/building_registry_source.dart';

/// Full-screen 360° tour for a campus building.
///
/// Reached from the building detail sheet on the Map tab, and by deep link at
/// `/map/building/:buildingId/360`.
class IndoorPreviewPage extends ConsumerWidget {
  const IndoorPreviewPage({
    super.key,
    required this.buildingId,
    this.initialSceneId,
  });

  final String buildingId;

  /// Scene to open on, when the caller knows which one it wants — e.g. a deep
  /// link to a specific theatre inside a building opens that panorama rather
  /// than the entrance.
  final String? initialSceneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final manifestAsync = ref.watch(indoorManifestProvider(buildingId));

    // Title comes from the same building registry the map and search use, so
    // the viewer names a place exactly as the rest of the app does. Falls back
    // to the id while the registry is still loading.
    final buildings = ref.watch(buildingRegistryProvider).value;
    final match = buildings
        ?.where((b) => b.id == buildingId)
        .cast<dynamic>()
        .firstOrNull;
    final title = (match?.name as String?) ?? buildingId;

    return Scaffold(
      // The panorama runs full-bleed behind the app bar.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
      ),
      body: manifestAsync.when(
        data: (manifest) => (manifest == null || manifest.isEmpty)
            ? Center(child: Text(l10n.indoorNoPreview))
            : IndoorTourView(manifest: manifest, firstSceneId: initialSceneId),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.indoorPreviewLoadError(e.toString()))),
      ),
    );
  }
}
