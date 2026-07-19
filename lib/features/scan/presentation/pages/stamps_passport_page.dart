import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_progress_ring.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';

class StampsPassportPage extends ConsumerWidget {
  const StampsPassportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catalogAsync = ref.watch(stampCatalogProvider);
    final visitedCodes = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.visitedLocationCodes ?? const <String>[],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stampsPassportTitle)),
      body: catalogAsync.when(
        data: (catalog) {
          final visitedUpper = visitedCodes.map((c) => c.toUpperCase()).toSet();
          final collectedCount = catalog
              .where((e) => visitedUpper.contains(e.locationId.toUpperCase()))
              .length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(MqSpacing.space4),
                child: StampProgressRing(
                  collected: collectedCount,
                  total: catalog.length,
                  size: 88,
                ),
              ),
              if (catalog.isNotEmpty && collectedCount == catalog.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: MqSpacing.space4),
                  child: Text(
                    l10n.stampCelebrationCompleteTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: MqColors.red,
                    ),
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(MqSpacing.space4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: MqSpacing.space3,
                    mainAxisSpacing: MqSpacing.space3,
                  ),
                  itemCount: catalog.length,
                  itemBuilder: (context, index) {
                    final entry = catalog[index];
                    final collected = visitedUpper.contains(
                      entry.locationId.toUpperCase(),
                    );
                    return _StampCell(
                      entry: entry,
                      collected: collected,
                      onTap: collected
                          ? () => context.push('/location/${entry.locationId}')
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
        error: (_, _) => Center(child: Text(l10n.settingsError)),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: MqColors.red)),
      ),
    );
  }
}

class _StampCell extends StatelessWidget {
  const _StampCell({required this.entry, required this.collected, this.onTap});

  final StampCatalogEntry entry;
  final bool collected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    // The locked-stamp neutral must flip to a light ink in dark mode; a fixed
    // charcoal background/border/icon is invisible on the dark scaffold.
    final neutral = isDark ? Colors.white : MqColors.charcoal800;
    final primaryText = isDark
        ? MqColors.contentPrimaryDark
        : MqColors.contentPrimary;
    final secondaryText = isDark
        ? MqColors.contentSecondaryDark
        : MqColors.contentSecondary;
    return Semantics(
      label: collected
          ? entry.title
          : '${entry.title}. ${l10n.stampsPassportLockedHint}',
      button: collected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(MqSpacing.space2),
          decoration: BoxDecoration(
            color: collected
                ? MqColors.red.withValues(alpha: isDark ? 0.14 : 0.06)
                : neutral.withValues(alpha: isDark ? 0.07 : 0.04),
            borderRadius: BorderRadius.circular(MqSpacing.radiusLg),
            border: Border.all(
              color: collected
                  ? MqColors.red.withValues(alpha: isDark ? 0.40 : 0.25)
                  : neutral.withValues(alpha: isDark ? 0.16 : 0.08),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (collected)
                Image.asset(
                  entry.stampAsset,
                  width: 40,
                  height: 40,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.local_activity,
                    size: 32,
                    color: MqColors.red,
                  ),
                )
              else
                Icon(
                  Icons.local_activity_outlined,
                  size: 32,
                  color: neutral.withValues(alpha: isDark ? 0.35 : 0.25),
                ),
              const SizedBox(height: MqSpacing.space1),
              Text(
                entry.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: collected ? primaryText : secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
