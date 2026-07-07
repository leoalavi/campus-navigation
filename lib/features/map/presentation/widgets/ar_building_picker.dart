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

  /// Display name for a building id: prefer the registry's official name
  /// ("29 Wally's Walk"), never show the raw slug ("wallys-29") to users.
  String _displayName(String id) {
    final registry = ref.watch(buildingsRegistryProvider).value;
    final name = registry?.byCode(id)?.name.trim() ?? '';
    return name.isNotEmpty ? name : id;
  }

  /// Alphabetical with natural number ordering, so "1 Wally's Walk" <
  /// "17 Wally's Walk" < "25 Wally's Walk" (plain string sort would give
  /// 1, 17, 25, 29 vs 1, 17, 21 — and put "10 Hadenfeld" before "1 Wally's").
  int _naturalCompare(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final as = re.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
    final bs = re.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
    for (var i = 0; i < as.length && i < bs.length; i++) {
      final an = int.tryParse(as[i]);
      final bn = int.tryParse(bs[i]);
      final cmp = (an != null && bn != null)
          ? an.compareTo(bn)
          : as[i].compareTo(bs[i]);
      if (cmp != 0) return cmp;
    }
    return as.length.compareTo(bs.length);
  }

  @override
  Widget build(BuildContext context) {
    final manifestStates = widget.buildingIds
        .map((id) => ref.watch(indoorManifestProvider(id)))
        .toList();

    final registryLoaded = ref.watch(buildingsRegistryProvider).hasValue;
    final allLoaded = manifestStates.every((s) => s.hasValue) && registryLoaded;
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
    hasManifest.sort(
      (a, b) => _naturalCompare(_displayName(a), _displayName(b)),
    );
    noManifest.sort(
      (a, b) => _naturalCompare(_displayName(a), _displayName(b)),
    );

    if (hasManifest.length == 1 && !_autoSelected) {
      _autoSelected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSelect(hasManifest.first);
      });
      return const Center(child: CircularProgressIndicator());
    }

    // The picker renders full-bleed beneath MapShell's floating Campus
    // Map / AR toggle, so reserve the toggle zone (safe area + pill height)
    // at the top — otherwise the first rows sit hidden behind the control.
    final topInset = MediaQuery.paddingOf(context).top + 76.0;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 16.0;
    return ListView.separated(
      padding: EdgeInsetsDirectional.only(top: topInset, bottom: bottomInset),
      itemCount: hasManifest.length + noManifest.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index < hasManifest.length) {
          final id = hasManifest[index];
          return ListTile(
            leading: const Icon(Icons.view_in_ar_outlined),
            title: Text(_displayName(id)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onSelect(id),
          );
        }
        final id = noManifest[index - hasManifest.length];
        return ListTile(
          leading: const Icon(Icons.view_in_ar_outlined),
          title: Text(_displayName(id)),
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
