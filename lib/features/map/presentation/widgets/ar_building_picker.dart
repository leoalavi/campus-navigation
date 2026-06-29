import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';

class ArBuildingPicker extends ConsumerWidget {
  const ArBuildingPicker({super.key, required this.onSelect});

  final void Function(String buildingId) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final trailAsync = ref.watch(trailManifestProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return trailAsync.when(
      data: (trail) {
        final buildingIds = trail.locations
            .map((l) => l.buildingId)
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

        if (buildingIds.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.arNoBuildingSelected),
            ),
          );
        }

        return _ManifestAwarePicker(
          buildingIds: buildingIds,
          onSelect: onSelect,
          l10n: l10n,
          isDark: isDark,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.scanNotOnTrail)),
    );
  }
}

class _ManifestAwarePicker extends ConsumerStatefulWidget {
  const _ManifestAwarePicker({
    required this.buildingIds,
    required this.onSelect,
    required this.l10n,
    required this.isDark,
  });

  final List<String> buildingIds;
  final void Function(String) onSelect;
  final AppLocalizations l10n;
  final bool isDark;

  @override
  ConsumerState<_ManifestAwarePicker> createState() =>
      _ManifestAwarePickerState();
}

class _ManifestAwarePickerState extends ConsumerState<_ManifestAwarePicker> {
  bool _autoSelected = false;

  @override
  Widget build(BuildContext context) {
    final manifestStates = widget.buildingIds
        .map((id) => ref.watch(indoorManifestProvider(id)))
        .toList();

    final allLoaded = manifestStates.every((s) => s.hasValue);
    if (!allLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasManifest = <String>[];
    final noManifest = <String>[];
    for (var i = 0; i < widget.buildingIds.length; i++) {
      if (manifestStates[i].value != null) {
        hasManifest.add(widget.buildingIds[i]);
      } else {
        noManifest.add(widget.buildingIds[i]);
      }
    }

    if (hasManifest.length == 1 && !_autoSelected) {
      _autoSelected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSelect(hasManifest.first);
      });
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: hasManifest.length + noManifest.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index < hasManifest.length) {
          final id = hasManifest[index];
          return ListTile(
            title: Text(id),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onSelect(id),
          );
        }
        final id = noManifest[index - hasManifest.length];
        return ListTile(
          title: Text(id),
          subtitle: Text(widget.l10n.arComingSoon),
          enabled: false,
          trailing: Icon(
            Icons.lock,
            color: widget.isDark ? Colors.white24 : Colors.black26,
          ),
        );
      },
    );
  }
}
