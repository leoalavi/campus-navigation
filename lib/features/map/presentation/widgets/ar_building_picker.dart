import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
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
    final sceneCounts = <String, int>{};
    for (var i = 0; i < widget.buildingIds.length; i++) {
      final manifest = manifestStates[i].value;
      // An empty manifest is as unavailable as a missing one (matches
      // IndoorPreviewPage, which shows "no preview" for an empty manifest).
      if (manifest != null && !manifest.isEmpty) {
        hasManifest.add(widget.buildingIds[i]);
        sceneCounts[widget.buildingIds[i]] = manifest.nodes.length;
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
    final l10n = widget.l10n;
    return ListView(
      padding: EdgeInsetsDirectional.only(
        top: topInset,
        bottom: bottomInset,
        start: MqSpacing.space4,
        end: MqSpacing.space4,
      ),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 6,
            bottom: MqSpacing.space4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.arExploreEyebrow,
                style: const TextStyle(
                  color: MqColors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 6),
              Semantics(
                header: true,
                child: Text(
                  l10n.arExploreTitle,
                  style: TextStyle(
                    color: widget.isDark
                        ? Colors.white
                        : MqColors.contentPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.arExploreSubtitle,
                style: TextStyle(
                  color: widget.isDark
                      ? MqColors.contentSecondaryDark
                      : MqColors.contentSecondary,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
        for (final id in hasManifest)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.space3),
            child: _ArBuildingCard(
              name: _displayName(id),
              subtitle: l10n.arSceneCount(sceneCounts[id]!),
              isDark: widget.isDark,
              onTap: () => widget.onSelect(id),
            ),
          ),
        for (final id in noManifest)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.space3),
            child: _ArBuildingCard(
              name: _displayName(id),
              subtitle: l10n.arTourComingSoon,
              isDark: widget.isDark,
              locked: true,
              soonLabel: l10n.arSoonPill,
            ),
          ),
      ],
    );
  }
}

/// A solid (non-glass) building card styled to match the app's glass
/// aesthetic. Solid because it sits over a solid ground — a per-row
/// `BackdropFilter` there would blur nothing and cost GPU.
class _ArBuildingCard extends StatelessWidget {
  const _ArBuildingCard({
    required this.name,
    required this.subtitle,
    required this.isDark,
    this.onTap,
    this.locked = false,
    this.soonLabel,
  }) : assert(locked || onTap != null),
       assert(!locked || onTap == null),
       assert(!locked || soonLabel != null);

  final String name;
  final String subtitle;
  final bool isDark;
  final VoidCallback? onTap;
  final bool locked;
  final String? soonLabel;

  @override
  Widget build(BuildContext context) {
    final neutral = isDark ? Colors.white : MqColors.charcoal800;
    final radius = BorderRadius.circular(MqSpacing.radiusXl);
    // No whole-card Opacity — locked info stays readable. Muted-but-accessible.
    final titleColor = locked
        ? (isDark ? MqColors.contentSecondaryDark : MqColors.contentSecondary)
        : (isDark ? Colors.white : MqColors.contentPrimary);
    final subColor = isDark
        ? MqColors.contentSecondaryDark
        : MqColors.contentSecondary;

    final decoration = BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: locked ? 0.04 : 0.06)
          : Colors.white,
      borderRadius: radius,
      border: Border.all(
        color: neutral.withValues(alpha: isDark ? 0.12 : 0.10),
      ),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: MqColors.charcoal800.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
    );

    final content = Padding(
      padding: const EdgeInsets.all(MqSpacing.space4),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: locked
                  ? null
                  : const LinearGradient(
                      colors: [MqColors.red, MqColors.deepRed],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: locked ? neutral.withValues(alpha: 0.10) : null,
            ),
            child: Icon(
              locked ? Icons.lock_outline_rounded : Icons.view_in_ar_outlined,
              color: locked ? neutral.withValues(alpha: 0.6) : Colors.white,
            ),
          ),
          const SizedBox(width: MqSpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subColor, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: MqSpacing.space3),
          if (locked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
                color: neutral.withValues(alpha: 0.12),
              ),
              child: Text(
                soonLabel!,
                style: TextStyle(
                  color: subColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const Icon(Icons.chevron_right_rounded, color: MqColors.red),
        ],
      ),
    );

    if (locked) {
      return Semantics(
        excludeSemantics: true,
        label: '$name, $subtitle',
        child: DecoratedBox(decoration: decoration, child: content),
      );
    }
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$name, $subtitle',
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          // Ink (not a Container under InkWell) so the splash shows.
          decoration: decoration,
          child: InkWell(borderRadius: radius, onTap: onTap, child: content),
        ),
      ),
    );
  }
}
