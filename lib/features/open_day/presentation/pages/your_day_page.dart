import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/map/data/datasources/building_registry_source.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_progress.dart';
import 'package:mq_journey/features/open_day/domain/services/open_day_time.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';

/// Dedicated "Your Day" screen — the user's personal saved itinerary ONLY.
///
/// This is intentionally a *different destination* from the Open Day schedule
/// ([OpenDayPage], which "Coming Up Next" opens). Your Day shows nothing but
/// the sessions and stops the user explicitly saved, with a clear empty state
/// when nothing has been added yet.
class YourDayPage extends ConsumerWidget {
  const YourDayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final items = ref.watch(userDayItemsProvider);

    return Scaffold(
      backgroundColor: dark ? MqColors.charcoal800 : MqColors.alabaster,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: l10n.back,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(RouteNames.home),
        ),
        title: Text(
          l10n.openDay_yourDayTitle,
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              // Wiping the whole plan is irreversible — one accidental tap on
              // an app-bar text button shouldn't destroy a curated day, so
              // confirm first.
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    content: Text(l10n.openDay_clearMyDayConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: TextButton.styleFrom(
                          foregroundColor: dark
                              ? MqColors.brightRed
                              : MqColors.red,
                        ),
                        child: Text(l10n.openDay_clearMyDay),
                      ),
                    ],
                  ),
                );
                if (confirmed ?? false) {
                  await ref
                      .read(settingsControllerProvider.notifier)
                      .clearSavedOpenDayEvents();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: dark ? MqColors.brightRed : MqColors.red,
              ),
              child: Text(l10n.openDay_clearMyDay),
            ),
        ],
      ),
      body: items.isEmpty
          ? _EmptyYourDay()
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MqSpacing.space5,
                MqSpacing.space4,
                MqSpacing.space5,
                MqSpacing.space12,
              ),
              children: [
                for (final item in items)
                  if (item is UserDaySession)
                    _SavedDayRow(event: item.event)
                  else if (item is UserDayStop)
                    _SavedStopRow(stop: item.stop),
              ],
            ),
    );
  }
}

class _EmptyYourDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(MqSpacing.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_add_outlined,
              size: 56,
              color: dark ? MqColors.slate500 : MqColors.charcoal600,
            ),
            const SizedBox(height: MqSpacing.space4),
            Text(
              l10n.openDay_yourDayEmpty,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: dark
                    ? Colors.white.withValues(alpha: 0.80)
                    : MqColors.contentSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedDayRow extends ConsumerWidget {
  const _SavedDayRow({required this.event});

  final OpenDayEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDarkMode;
    final time = OpenDayTime.formatTimeOfDay(event.startTime);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: MqSpacing.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              time,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : MqColors.contentPrimary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : MqColors.contentPrimary,
                  ),
                ),
                Text(
                  event.venueName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.72)
                        : MqColors.contentSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (event.buildingCode != null)
            _ShowOnMapButton(buildingCode: event.buildingCode!),
          _RemoveButton(
            onTap: () => ref
                .read(settingsControllerProvider.notifier)
                .toggleSavedOpenDayEvent(event.id),
          ),
        ],
      ),
    );
  }
}

class _SavedStopRow extends ConsumerWidget {
  const _SavedStopRow({required this.stop});

  final OpenDaySuggestedStop stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: MqSpacing.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Icon(
              Icons.place_outlined,
              size: 18,
              color: dark ? MqColors.brightRed : MqColors.red,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : MqColors.contentPrimary,
                  ),
                ),
                Text(
                  stop.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.72)
                        : MqColors.contentSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (stop.buildingCode != null)
            _ShowOnMapButton(buildingCode: stop.buildingCode!),
          _RemoveButton(
            onTap: () => ref
                .read(settingsControllerProvider.notifier)
                .toggleSavedStop(stop.id),
          ),
        ],
      ),
    );
  }
}

/// Opens a saved item's location on the Campus Map.
class _ShowOnMapButton extends ConsumerWidget {
  const _ShowOnMapButton({required this.buildingCode});

  final String buildingCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    return Semantics(
      button: true,
      label: l10n.openDay_viewInCampusMap,
      child: InkWell(
        onTap: () {
          final buildings = ref.read(buildingRegistryProvider).value;
          final resolved = _resolveBuildingByCode(buildings, buildingCode);
          final targetId = resolved?.id ?? buildingCode;
          // Re-emit the selection so the marker re-shows even if the same
          // location was opened and closed before (same-URL no-op guard).
          // Always land on the Campus Map, never a remembered AR view.
          ref.read(campusMapIntentProvider.notifier).bump();
          ref.read(mapControllerProvider.notifier).selectBuildingById(targetId);
          context.goNamed(
            RouteNames.map,
            queryParameters: {'building': targetId},
          );
        },
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(MqSpacing.space1),
          child: Icon(
            Icons.map_outlined,
            size: 18,
            color: dark ? MqColors.brightRed : MqColors.red,
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    return Semantics(
      button: true,
      label: l10n.openDay_removeFromMyDay,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(MqSpacing.space1),
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: dark
                ? Colors.white.withValues(alpha: 0.6)
                : MqColors.contentTertiary,
          ),
        ),
      ),
    );
  }
}

Building? _resolveBuildingByCode(List<Building>? buildings, String code) {
  if (buildings == null) return null;
  final upper = code.toUpperCase();
  for (final b in buildings) {
    if (b.code.toUpperCase() == upper || b.id.toUpperCase() == upper) {
      return b;
    }
  }
  return null;
}
