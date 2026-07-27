import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/map/presentation/actions/open_building_on_map.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_progress.dart';
import 'package:mq_journey/features/open_day/domain/services/open_day_personalisation.dart';
import 'package:mq_journey/features/open_day/domain/services/open_day_time.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';
import 'package:mq_journey/shared/widgets/mq_tactile_button.dart';

/// The personalised Open Day sections shown on Home once the user has chosen
/// a study interest:
///
///   1. Live Now / Coming Up Next  — current + upcoming sessions, biased to
///      the selected interest.
///   2. Suggested Stops            — featured campus locations for the
///      interest (gated by the minimal `showSuggestedStops` setting).
///   3. Your Day                   — the lightweight saved-itinerary entry
///      point.
///
/// Renders nothing until a bachelor is selected, so Home stays clean for new
/// users — the existing `OpenDayHomeCard` handles the onboarding prompt. All
/// relevance logic lives in providers / [OpenDayPersonalisation]; this file is
/// presentation only.
class OpenDayPersonalisedSections extends ConsumerWidget {
  const OpenDayPersonalisedSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(openDayDataProvider);
    final selected = ref.watch(selectedBachelorProvider);
    // Only personalise once we have both data and a chosen interest.
    if (dataAsync is! AsyncData<OpenDayData> || selected == null) {
      return const SizedBox.shrink();
    }

    final showSuggested =
        ref.watch(settingsControllerProvider).value?.showSuggestedStops ?? true;

    // Study-interest cluster (sits directly under the interest card):
    //   Coming Up Next → Suggested Stops.
    // "Your Day" is intentionally NOT here — it lives in its own
    // [OpenDayYourDayCard] so it shows independently of interest selection.
    return Column(
      children: [
        const SizedBox(height: MqSpacing.space4),
        const _LiveNowCard(),
        if (showSuggested) ...[
          const SizedBox(height: MqSpacing.space4),
          SuggestedStopsSection(interestName: selected.name),
        ],
      ],
    );
  }
}

/// Standalone "Your Day" card for Home. Independent of study-interest
/// selection — it shows whenever the Open Day dataset is available, with an
/// empty state prompting the user to save sessions/stops. This is the user's
/// personal saved flow, so it must never disappear just because no interest
/// was picked.
class OpenDayYourDayCard extends ConsumerWidget {
  const OpenDayYourDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(openDayDataProvider);
    if (dataAsync is! AsyncData<OpenDayData>) return const SizedBox.shrink();
    return const _YourDayCard();
  }
}

// -------------------------------------------------------------------------- //
// SHARED STYLING                                                            //
// -------------------------------------------------------------------------- //

BoxDecoration _glassCard(bool dark) {
  return BoxDecoration(
    color: dark
        ? MqColors.charcoal800.withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.94),
    borderRadius: BorderRadius.circular(MqSpacing.radiusXl),
    border: Border.all(
      color: dark
          ? Colors.white.withValues(alpha: 0.08)
          : MqColors.charcoal800.withValues(alpha: 0.06),
      width: 0.6,
    ),
    boxShadow: [
      BoxShadow(
        color: MqColors.charcoal800.withValues(alpha: dark ? 0.30 : 0.10),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

/// Maps the data-driven icon name to a const [IconData]. A `switch` over
/// const `Icons.*` keeps Flutter's icon tree-shaker happy (constructing
/// `IconData` from raw codepoints would disable it).
IconData iconForStop(String name) {
  return switch (name) {
    'memory' => Icons.memory,
    'engineering' => Icons.engineering,
    'precision_manufacturing' => Icons.precision_manufacturing,
    'biotech' => Icons.biotech,
    'eco' => Icons.eco,
    'auto_awesome' => Icons.auto_awesome,
    'calculate' => Icons.calculate,
    'health_and_safety' => Icons.health_and_safety,
    'local_hospital' => Icons.local_hospital,
    'psychology' => Icons.psychology,
    'hearing' => Icons.hearing,
    'palette' => Icons.palette,
    'image' => Icons.image,
    'museum' => Icons.museum,
    'business_center' => Icons.business_center,
    'rocket_launch' => Icons.rocket_launch,
    'local_library' => Icons.local_library,
    'groups' => Icons.groups,
    'restaurant' => Icons.restaurant,
    _ => Icons.place,
  };
}

/// Resolves a building code into the registry and routes to it on the Campus
/// Map.
///
/// **Why it also selects imperatively:** navigating to the same
/// `/map?building=X` URL the user opened before is a no-op for go_router (the
/// kept-alive MapPage isn't rebuilt and its param handler never re-runs), so
/// after closing a location with X and tapping the same stop again, nothing
/// happened. Calling `selectBuildingById` first re-emits the selection state
/// every time, guaranteeing the marker re-shows on repeated taps; the
/// `goNamed` keeps the URL in sync.
void _openOnMap(BuildContext context, WidgetRef ref, String? buildingCode) {
  if (buildingCode == null) return;
  openBuildingOnCampusMap(context, buildingCode);
}

/// Prominent section header for the Suggested Stops block.
///
/// Renders a single high-contrast chip. The study interest is merged into
/// [title] by the caller (e.g. "Suggested stops for Bachelor of Computing"),
/// so there is deliberately no secondary subtitle line — a separate caption
/// read poorly against the photo background.
class _OpenDaySectionHeader extends StatelessWidget {
  const _OpenDaySectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: MqSpacing.space1,
        bottom: MqSpacing.space3,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark
                ? MqColors.black.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(MqSpacing.radiusMd),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.10)
                  : MqColors.black.withValues(alpha: 0.14),
              width: 0.8,
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              MqSpacing.space3,
              MqSpacing.space2,
              MqSpacing.space3,
              MqSpacing.space2,
            ),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                height: 1.15,
                color: dark ? Colors.white : MqColors.charcoal800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------- //
// LIVE NOW / COMING UP NEXT                                                  //
// -------------------------------------------------------------------------- //

class _LiveNowCard extends ConsumerWidget {
  const _LiveNowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final status = ref.watch(openDayLiveStatusProvider);

    if (status.isEmpty) return const SizedBox.shrink();

    final hasLive = status.liveNow.isNotEmpty;
    final event = hasLive ? status.liveNow.first : status.comingUpNext!;
    final eyebrow = hasLive
        ? l10n.openDay_liveNowTitle
        : l10n.openDay_comingUpNextTitle;
    final scopeLabel = status.usedFallback
        ? l10n.openDay_liveNowAcrossDay
        : l10n.openDay_liveNowForInterest;

    final time = hasLive
        ? OpenDayTime.formatTimeRange(event.startTime, event.endTime)
        : OpenDayTime.formatTimeOfDay(event.startTime);
    final extraLive = status.liveNow.length - 1;

    return MqTactileButton(
      onTap: () => context.pushNamed(RouteNames.openDay),
      borderRadius: MqSpacing.radiusXl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(MqSpacing.space4),
        decoration: _glassCard(dark),
        child: Row(
          children: [
            _LivePip(active: hasLive),
            const SizedBox(width: MqSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        eyebrow.toUpperCase(),
                        style: context.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: MqColors.red,
                        ),
                      ),
                      const SizedBox(width: MqSpacing.space2),
                      Flexible(
                        child: Text(
                          '· $scopeLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: dark
                                ? Colors.white.withValues(alpha: 0.7)
                                : MqColors.contentSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : MqColors.contentPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    extraLive > 0
                        ? '$time  ·  ${event.venueName}  ·  +$extraLive'
                        : '$time  ·  ${event.venueName}',
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
            const Icon(Icons.chevron_right_rounded, color: MqColors.brightRed),
          ],
        ),
      ),
    );
  }
}

/// Small status dot — solid red when a session is live, hollow when the next
/// one is merely upcoming.
class _LivePip extends StatelessWidget {
  const _LivePip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: active ? MqColors.red : MqColors.red.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        active ? Icons.sensors_rounded : Icons.schedule_rounded,
        color: active ? Colors.white : MqColors.red,
        size: 22,
      ),
    );
  }
}

// -------------------------------------------------------------------------- //
// SUGGESTED STOPS                                                            //
// -------------------------------------------------------------------------- //

class SuggestedStopsSection extends ConsumerWidget {
  const SuggestedStopsSection({super.key, required this.interestName});

  final String interestName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stops = ref.watch(suggestedStopsProvider);
    if (stops.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OpenDaySectionHeader(
          // Interest merged into the title itself — avoids a separate,
          // low-contrast subtitle line floating over the photo background.
          title: l10n.openDay_suggestedStopsForInterest(interestName),
        ),
        const _TrailProgressChip(),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: MqSpacing.space1),
            itemCount: stops.length,
            separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.space3),
            itemBuilder: (context, i) => _SuggestedStopCard(stop: stops[i]),
          ),
        ),
      ],
    );
  }
}

/// Slim, secondary gamification chip: "Visited X of N stops" + XP, with a
/// "trail complete" flourish. Hides itself until the user has visited at
/// least one stop, so it never nags a brand-new visitor.
class _TrailProgressChip extends ConsumerWidget {
  const _TrailProgressChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final progress = ref.watch(visitProgressProvider);
    if (!progress.hasTrail || progress.visitedCount == 0) {
      return const SizedBox.shrink();
    }

    final label = progress.trailComplete && progress.trailName != null
        ? l10n.openDay_trailCompleted(progress.trailName!)
        : l10n.openDay_progressVisited(
            progress.visitedCount,
            progress.totalCount,
          );

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: MqSpacing.space1,
        bottom: MqSpacing.space3,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            progress.trailComplete
                ? Icons.emoji_events_rounded
                : Icons.flag_outlined,
            size: 16,
            color: dark ? MqColors.brightRed : MqColors.red,
          ),
          const SizedBox(width: MqSpacing.space2),
          Flexible(
            child: Text(
              '$label  ·  ${progress.xp} XP',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : MqColors.charcoal800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedStopCard extends ConsumerWidget {
  const _SuggestedStopCard({required this.stop});

  final OpenDaySuggestedStop stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final tappable = stop.buildingCode != null;
    final isSaved =
        ref.watch(settingsControllerProvider).value?.isStopSaved(stop.id) ??
        false;

    return Semantics(
      button: tappable,
      label: stop.title,
      child: MqTactileButton(
        // Whole-card tap opens the stop on the Campus Map.
        onTap: () => _openOnMap(context, ref, stop.buildingCode),
        borderRadius: MqSpacing.radiusXl,
        child: Container(
          width: 220,
          padding: const EdgeInsetsDirectional.all(MqSpacing.space4),
          decoration: _glassCard(dark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: MqColors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconForStop(stop.icon),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  // Add-to / remove-from "Your Day" toggle. Its own tap
                  // target so it doesn't trigger the card's open-on-map tap.
                  Semantics(
                    button: true,
                    label: isSaved
                        ? l10n.openDay_removeFromMyDay
                        : l10n.openDay_addToMyDay,
                    child: InkWell(
                      onTap: () async {
                        await ref
                            .read(settingsControllerProvider.notifier)
                            .toggleSavedStop(stop.id);
                        if (context.mounted) {
                          context.showSnackBar(
                            isSaved
                                ? l10n.openDay_removedFromMyDay
                                : l10n.openDay_savedToMyDay,
                          );
                        }
                      },
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(2),
                        child: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_add_outlined,
                          size: 20,
                          color: isSaved
                              ? MqColors.red
                              : (dark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : MqColors.contentTertiary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MqSpacing.space3),
              Text(
                stop.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : MqColors.contentPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  stop.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    height: 1.3,
                    color: dark
                        ? Colors.white.withValues(alpha: 0.72)
                        : MqColors.contentSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------- //
// YOUR DAY                                                                   //
// -------------------------------------------------------------------------- //

class _YourDayCard extends ConsumerWidget {
  const _YourDayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final items = ref.watch(userDayItemsProvider);
    final isEmpty = items.isEmpty;

    return MqTactileButton(
      // Your Day has its own destination (saved items only) — distinct from
      // Coming Up Next, which opens the broader Open Day schedule.
      onTap: () => context.pushNamed(RouteNames.yourDay),
      borderRadius: MqSpacing.radiusXl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(MqSpacing.space4),
        decoration: _glassCard(dark),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isEmpty
                    ? MqColors.red.withValues(alpha: 0.12)
                    : MqColors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEmpty ? Icons.bookmark_add_outlined : Icons.bookmark_rounded,
                color: isEmpty ? MqColors.red : Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: MqSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.openDay_yourDayTitle,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : MqColors.contentPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEmpty
                        ? l10n.openDay_yourDayEmpty
                        : _savedSummary(items, l10n),
                    maxLines: 2,
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
            const Icon(Icons.chevron_right_rounded, color: MqColors.brightRed),
          ],
        ),
      ),
    );
  }

  /// Summary line for the Home card:
  ///   • exactly one saved item → count + that item's detail (helpful);
  ///   • multiple items → just the count (appending only the first item's
  ///     time/venue was confusing — it looked like one item was singled out).
  String _savedSummary(List<UserDayItem> items, AppLocalizations l10n) {
    final count = l10n.openDay_yourDayCount(items.length);
    if (items.length != 1) return count;

    final item = items.first;
    if (item is UserDaySession) {
      final e = item.event;
      return '$count  ·  '
          '${OpenDayTime.formatTimeOfDay(e.startTime)} ${e.venueName}';
    }
    if (item is UserDayStop) return '$count  ·  ${item.stop.title}';
    return count;
  }
}
