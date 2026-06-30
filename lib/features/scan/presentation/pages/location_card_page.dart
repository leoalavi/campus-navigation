import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/scan/domain/contracts/location_content.dart';
import 'package:mq_journey/features/scan/domain/contracts/my_day_entry.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/presentation/widgets/card_visit_badge.dart';
import 'package:mq_journey/features/scan/presentation/widgets/open_day_stops_table.dart';
import 'package:mq_journey/features/scan/presentation/widgets/photo_gallery.dart';
import 'package:mq_journey/features/scan/presentation/widgets/schedule_chips.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';

bool arEnabled(TrailLocation? loc) {
  if (loc == null) return false;
  return loc.arSceneId != null || loc.stops.any((s) => s.arSceneId.isNotEmpty);
}

class LocationCardPage extends ConsumerWidget {
  const LocationCardPage({super.key, required this.locationId});
  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(locationContentProvider(locationId));
    final schedule = ref.watch(scheduleProvider);
    final trail = ref.watch(trailManifestProvider).value;
    final registry = ref.watch(buildingsRegistryProvider).value;

    if (content == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final loc = trail?.byId(locationId);
    // Campus-Map button is enabled only when the building resolves to a real
    // entry in buildings.json (spec §5: "a building with entrance coords"),
    // never just because a buildingId string is present.
    final mapEnabled =
        content.buildingId != null &&
        registry?.byCode(content.buildingId!) != null;
    final visitedAsync = ref.watch(
      visitedStateProvider(content.buildingId ?? locationId),
    );
    final visited =
        visitedAsync.asData?.value ??
        const VisitedState(visited: false, rewardEarned: false);
    // Card-level Live/Next chips are keyed by locationId (existing behaviour);
    // they collapse to nothing when the partner schedule has no match. If the
    // partner keys schedule only at stop level, reconcile this key in Phase 5/6.
    final liveNow = schedule.liveNow(locationId);
    final nextUp = schedule.comingUpNext(locationId);

    return Scaffold(
      appBar: AppBar(title: Text(content.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhotoGallery(
              photos: loc?.photos ?? const [],
              fallbackAsset: content.heroImageAsset,
            ),
            const SizedBox(height: 16),
            Text(
              content.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              content.shortDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _PrimaryButtons(content: content, loc: loc, mapEnabled: mapEnabled),
            const SizedBox(height: 16),
            OpenDayStopsTable(
              stops: loc?.stops ?? const [],
              schedule: schedule,
              onTapStop: (stop) => context.goNamed(
                RouteNames.locationAr,
                pathParameters: {'locationId': locationId},
                queryParameters: {'stop': stop.stopId},
              ),
            ),
            // Secondary region — spec §3 order: Add to Your Day · Full schedule
            // · Live/Next chips · Visited badge.
            const SizedBox(height: 16),
            _SecondaryActions(content: content),
            const SizedBox(height: 8),
            ScheduleChips(liveNow: liveNow, comingUpNext: nextUp),
            const SizedBox(height: 8),
            CardVisitBadge(state: visited),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButtons extends StatelessWidget {
  const _PrimaryButtons({
    required this.content,
    required this.loc,
    required this.mapEnabled,
  });
  final LocationContent content;
  final TrailLocation? loc;
  final bool mapEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: mapEnabled
                ? () => context.goNamed(
                    RouteNames.map,
                    queryParameters: {'building': content.buildingId!},
                  )
                : null,
            icon: const Icon(Icons.map),
            label: Text(l10n.cardViewOnCampusMap),
          ),
        ),
        if (arEnabled(loc)) ...[
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.goNamed(
                RouteNames.locationAr,
                pathParameters: {'locationId': content.locationId},
              ),
              icon: const Icon(Icons.view_in_ar),
              label: Text(l10n.cardViewArMap),
            ),
          ),
        ],
      ],
    );
  }
}

class _SecondaryActions extends ConsumerWidget {
  const _SecondaryActions({required this.content});
  final LocationContent content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheduleUrl = content.fullScheduleUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final addedMsg = l10n.cardAddToYourDay;
            final api = ref.read(myDayApiProvider);
            await api.addToDay(
              MyDayEntry(locationId: content.locationId, when: DateTime.now()),
            );
            if (context.mounted) {
              messenger.showSnackBar(SnackBar(content: Text(addedMsg)));
            }
          },
          icon: const Icon(Icons.calendar_today),
          label: Text(l10n.cardAddToYourDayCta),
        ),
        // Full schedule link — spec §3/§4; hidden when fullScheduleUrl is null.
        if (scheduleUrl != null && scheduleUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(scheduleUrl),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.cardFullSchedule),
          ),
        ],
      ],
    );
  }
}
