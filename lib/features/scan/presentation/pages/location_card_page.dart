import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/scan/application/pending_stamp_award_controller.dart';
import 'package:mq_journey/features/scan/domain/contracts/location_content.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/domain/services/stamp_award_calculator.dart';
import 'package:mq_journey/features/scan/presentation/widgets/card_visit_badge.dart';
import 'package:mq_journey/features/scan/presentation/widgets/photo_gallery.dart';
import 'package:mq_journey/features/scan/presentation/widgets/schedule_chips.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_earned_sheet.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';

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
    final pendingNotice = ref.watch(pendingStampAwardProvider);

    if (pendingNotice?.locationId == locationId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _consumePendingNotice(context, ref, locationId);
      });
    }

    if (content == null) {
      // Null means either "datasets still loading" or "no such location".
      // Distinguish them: content resolves from BOTH the trail manifest and the
      // buildings registry, so only treat a null as a genuinely unknown id
      // (stale QR poster, mistyped deep link) once BOTH have loaded — otherwise
      // a valid scan flashes the "not on trail" dead-end while the (large)
      // buildings.json is still loading. Show a spinner until then.
      final trailLoaded = ref.watch(trailManifestProvider).hasValue;
      final registryLoaded = ref.watch(buildingsRegistryProvider).hasValue;
      if (!trailLoaded || !registryLoaded) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final l10n = AppLocalizations.of(context)!;
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_outlined, size: 56),
                const SizedBox(height: 16),
                Text(l10n.scanNotOnTrail, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  l10n.scanNotOnTrailDesc,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.goNamed(RouteNames.home),
                  child: Text(l10n.back),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final loc = trail?.byId(locationId);
    // Campus-Map button is enabled only when the building resolves to a real
    // entry in buildings.json (spec §5: "a building with entrance coords"),
    // never just because a buildingId string is present. Prefer the explicit
    // mapBuildingCode (the campus-map code with real coordinates, e.g. "29WW")
    // over the trail buildingId slug ("wallys-29"), which resolves only to a
    // coordinate-less Open Day stub and would land the map on the (0,0) corner.
    final mapCode = content.mapBuildingCode ?? content.buildingId;
    final mapEnabled = mapCode != null && registry?.byCode(mapCode) != null;
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
      appBar: AppBar(
        title: Text(content.title),
        // QR scans navigate here with `go` (replacing the stack), so there is
        // often nothing to pop. Provide an explicit affordance: pop when
        // there's history (came from Scan), otherwise fall back to Home so
        // the user is never stranded on the detail screen.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: AppLocalizations.of(context)!.back,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(RouteNames.home),
        ),
      ),
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
            // The per-scene list (e.g. "Theatre 1") was removed from the venue
            // summary: it duplicated the AR entry point. Scene selection lives
            // inside the AR viewer itself (reached via "View AR map").
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

  Future<void> _consumePendingNotice(
    BuildContext context,
    WidgetRef ref,
    String locationId,
  ) async {
    final notice = ref
        .read(pendingStampAwardProvider.notifier)
        .consume(locationId);
    if (notice == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (notice.saveFailed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.scanVisitSaveFailed)));
      return;
    }

    final catalog = await ref.read(stampCatalogProvider.future);
    final visitedCodes =
        ref.read(settingsControllerProvider).value?.visitedLocationCodes ??
        const <String>[];
    final award = computeStampAward(
      visitedCode: locationId,
      visitedLocationCodesAfterVisit: visitedCodes,
      catalog: catalog,
    );
    if (award == null || !context.mounted) return;

    if (notice.isNewVisit) {
      final action = await showStampEarnedSheet(context, award);
      if (action == StampSheetAction.viewPassport && context.mounted) {
        unawaited(context.push('/stamps'));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.stampAlreadyCollected(award.stamp.title))),
      );
    }
  }
}

class _PrimaryButtons extends ConsumerWidget {
  const _PrimaryButtons({
    required this.content,
    required this.loc,
    required this.mapEnabled,
  });
  final LocationContent content;
  final TrailLocation? loc;
  final bool mapEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Full-width stacked buttons: side-by-side Expanded buttons squeezed the
    // long "View on Campus Map" label into a half-width box where it wrapped
    // on top of itself.
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: mapEnabled
                ? () {
                    // "View on Campus Map" must always show the map —
                    // never a remembered AR view on the Journey tab. Pass the
                    // resolved campus-map code (real coords), not the trail
                    // buildingId slug, so the map focuses the actual building.
                    ref.read(campusMapIntentProvider.notifier).bump();
                    context.goNamed(
                      RouteNames.map,
                      queryParameters: {
                        'building':
                            content.mapBuildingCode ?? content.buildingId!,
                      },
                    );
                  }
                : null,
            icon: const Icon(Icons.map),
            label: Text(l10n.cardViewOnCampusMap),
          ),
        ),
        if (arEnabled(loc)) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
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
    // Reflect the real saved state so the button doesn't silently toggle a
    // hidden flag: filled + "Added to Your Day" once saved, outlined + "Add
    // to Your Day" otherwise. Uses the same savedStopIds source as every
    // other Open Day save.
    final saved =
        ref
            .watch(settingsControllerProvider)
            .value
            ?.isStopSaved(content.locationId) ??
        false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        saved
            ? FilledButton.icon(
                onPressed: () =>
                    _toggleSaved(context, ref, l10n, wasSaved: true),
                icon: const Icon(Icons.check_rounded),
                label: Text(l10n.cardAddToYourDay),
              )
            : OutlinedButton.icon(
                onPressed: () =>
                    _toggleSaved(context, ref, l10n, wasSaved: false),
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

  Future<void> _toggleSaved(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    required bool wasSaved,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    // Same storage path as suggested stops (savedStopIds), so the venue shows
    // up on the Your Day screen and Home card and persists across launches.
    await ref
        .read(settingsControllerProvider.notifier)
        .toggleSavedStop(content.locationId);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          wasSaved ? l10n.openDay_removedFromMyDay : l10n.cardAddToYourDay,
        ),
      ),
    );
  }
}
