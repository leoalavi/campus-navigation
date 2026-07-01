import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/map/data/datasources/building_registry_source.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';
import 'package:mq_journey/shared/widgets/mq_bottom_sheet.dart';

class EventActionsSheet extends ConsumerWidget {
  const EventActionsSheet({super.key, required this.event});

  final OpenDayEvent event;

  static Future<void> show(BuildContext context, OpenDayEvent event) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EventActionsSheet(event: event),
    );

    if (context.mounted) {
      final container = ProviderScope.containerOf(context);
      final buildings = container.read(buildingRegistryProvider).value;
      final resolved = _resolveBuilding(buildings, event.buildingCode);
      final targetBuildingId = resolved?.id ?? event.buildingCode!;

      context.goNamed(
        RouteNames.map,
        queryParameters: {'building': targetBuildingId},
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final buildingsAsync = ref.watch(buildingRegistryProvider);
    final building = _resolveBuilding(buildingsAsync.value, event.buildingCode);
    final hasResolvedBuilding = event.buildingCode != null && building != null;

    return MqBottomSheet(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MqSpacing.space2,
          vertical: MqSpacing.space2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: MqSpacing.space2,
                vertical: MqSpacing.space1,
              ),
              child: Text(
                event.venueName,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : MqColors.contentPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MqSpacing.space2,
                0,
                MqSpacing.space2,
                MqSpacing.space2,
              ),
              child: Text(
                event.title,
                style: context.textTheme.bodySmall?.copyWith(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.72)
                      : MqColors.contentSecondary,
                ),
              ),
            ),
            if (hasResolvedBuilding) ...[
              Semantics(
                button: true,
                label: l10n.openDay_viewInCampusMapSemantic(event.venueName),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on_rounded,
                      color: dark ? MqColors.brightRed : MqColors.red,
                    ),
                    title: Text(
                      l10n.openDay_viewInCampusMap,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(l10n.openDay_openInsideMqNav),
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsetsDirectional.all(MqSpacing.space4),
                child: Text(l10n.openDay_noMappableVenue),
              ),
          ],
        ),
      ),
    );
  }

  static Building? _resolveBuilding(List<Building>? buildings, String? code) {
    if (buildings == null || code == null) return null;
    final upper = code.toUpperCase();
    for (final b in buildings) {
      if (b.code.toUpperCase() == upper || b.id.toUpperCase() == upper) {
        return b;
      }
    }
    return null;
  }
}
