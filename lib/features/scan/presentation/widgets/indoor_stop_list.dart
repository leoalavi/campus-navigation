import 'package:flutter/material.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';

class IndoorStopList extends StatelessWidget {
  const IndoorStopList({super.key, required this.manifest});
  final IndoorManifest manifest;

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
        return ListTile(
          leading: const Icon(Icons.location_on),
          title: Text(node.description.isNotEmpty ? node.description : node.id),
          subtitle: node.neighbours.isNotEmpty
              ? Text(l10n.indoorConnections(node.neighbours.length))
              : null,
        );
      },
    );
  }
}
