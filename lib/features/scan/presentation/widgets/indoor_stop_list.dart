import 'package:flutter/material.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';

class IndoorStopList extends StatelessWidget {
  const IndoorStopList({
    super.key,
    required this.manifest,
    this.selectedSceneId,
    this.onSceneSelected,
  });
  final IndoorManifest manifest;
  final String? selectedSceneId;
  final ValueChanged<String>? onSceneSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (manifest.isEmpty) {
      return Center(child: Text(l10n.indoorNoPreview));
    }
    return ListView.separated(
      itemCount: manifest.nodes.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final node = manifest.nodes[index];
        final selected = node.id == selectedSceneId;
        final accent = Theme.of(context).colorScheme.primary;
        return MouseRegion(
          cursor: onSceneSelected == null
              ? MouseCursor.defer
              : SystemMouseCursors.click,
          child: ListTile(
            selected: selected,
            selectedTileColor: accent.withValues(alpha: 0.12),
            leading: Icon(Icons.location_on, color: selected ? accent : null),
            title: Text(
              node.description.isNotEmpty ? node.description : node.id,
            ),
            subtitle: node.neighbours.isNotEmpty
                ? Text(l10n.indoorConnections(node.neighbours.length))
                : null,
            onTap: onSceneSelected == null
                ? null
                : () => onSceneSelected!(node.id),
          ),
        );
      },
    );
  }
}
