import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/open_day/domain/services/open_day_time.dart';
import 'package:mq_journey/features/open_day/presentation/widgets/bachelor_picker_sheet.dart';
import 'package:mq_journey/features/open_day/presentation/actions/open_event_venue.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';
import 'package:mq_journey/shared/widgets/mq_tactile_button.dart';

/// Dedicated Open Day screen. Lists events relevant to the user's
/// selected bachelor, grouped by time. If no bachelor has been picked,
/// shows a gentle CTA to pick one — the screen still works; it just
/// shows fewer events.
class OpenDayPage extends ConsumerWidget {
  const OpenDayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final dataAsync = ref.watch(openDayDataProvider);
    final selected = ref.watch(selectedBachelorProvider);
    final degreeSessions = ref.watch(degreeSessionsProvider);
    final generalSessions = ref.watch(generalSessionsProvider);

    return Scaffold(
      backgroundColor: dark ? MqColors.charcoal800 : MqColors.alabaster,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // GoRouter renders `/open-day` outside the bottom-nav shell, so
        // `automaticallyImplyLeading` doesn't always discover a back
        // affordance reliably. Wire one explicitly: pop if there's a
        // route to pop to (deep-link from Home), otherwise route the
        // user to Home — never a dead screen.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: l10n.back,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(RouteNames.home);
            }
          },
        ),
        title: Text(
          l10n.openDay_pageTitle,
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(MqSpacing.space6),
            child: Text(
              l10n.openDay_loadError,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium,
            ),
          ),
        ),
        data: (data) => _OpenDayBody(
          data: data,
          selected: selected,
          degreeSessions: degreeSessions,
          generalSessions: generalSessions,
        ),
      ),
    );
  }
}

class _OpenDayBody extends StatelessWidget {
  const _OpenDayBody({
    required this.data,
    required this.selected,
    required this.degreeSessions,
    required this.generalSessions,
  });

  final OpenDayData data;
  final OpenDayBachelor? selected;
  final List<OpenDayEvent> degreeSessions;
  final List<OpenDayEvent> generalSessions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasSelection = selected != null;
    final nothingToShow = degreeSessions.isEmpty && generalSessions.isEmpty;

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MqSpacing.space5,
        MqSpacing.space2,
        MqSpacing.space5,
        MqSpacing.space12,
      ),
      children: [
        _StudyInterestHeader(selected: selected, openDayDate: data.openDayDate),
        const SizedBox(height: MqSpacing.space5),

        if (nothingToShow) _EmptyEventsState(hasSelection: hasSelection),

        // 1. Degree-first section — ONLY sessions for the exact selected
        //    degree. Primary (red) header so it reads as the main content.
        if (hasSelection && degreeSessions.isNotEmpty) ...[
          _SessionSectionHeader(
            label: l10n.openDay_matchedToYourDegree,
            icon: Icons.school_rounded,
            primary: true,
          ),
          const SizedBox(height: MqSpacing.space3),
          ..._groupedByHour(degreeSessions),
          // Strong visual break before the secondary group.
          const SizedBox(height: MqSpacing.space6),
        ],

        // 2. General / open-to-all section — neutral header, clearly secondary
        //    and separated, so it never masquerades as degree-specific.
        if (generalSessions.isNotEmpty) ...[
          _SessionSectionHeader(
            label: hasSelection
                ? l10n.openDay_generalOpenToAll
                : l10n.openDay_allSessionsLabel,
            icon: Icons.groups_rounded,
            primary: true,
          ),
          const SizedBox(height: MqSpacing.space3),
          ..._groupedByHour(generalSessions),
        ],
      ],
    );
  }

  /// Builds a list of widgets where consecutive events sharing the same
  /// hour are visually grouped under a single time header.
  ///
  /// Hour-grouping uses `OpenDayTime.sydneyHour` so events that share an
  /// hour in Sydney always cluster together, regardless of device TZ.
  /// Headers and tile times use the same Sydney-aware formatter, so a
  /// 1:00 PM event reads as "1:00 PM" everywhere — never "3:00 AM" on
  /// a UTC device.
  List<Widget> _groupedByHour(List<OpenDayEvent> events) {
    final out = <Widget>[];
    int? currentHour;
    for (final e in events) {
      final hourKey = OpenDayTime.sydneyHour(e.startTime);
      if (hourKey != currentHour) {
        currentHour = hourKey;
        out.add(
          _TimeBlockHeader(label: OpenDayTime.formatTimeOfDay(e.startTime)),
        );
      }
      out.add(_EventTile(event: e));
      out.add(const SizedBox(height: MqSpacing.space3));
    }
    return out;
  }
}

class _StudyInterestHeader extends ConsumerWidget {
  const _StudyInterestHeader({
    required this.selected,
    required this.openDayDate,
  });

  final OpenDayBachelor? selected;
  final DateTime openDayDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final dateText = OpenDayTime.formatLongDate(openDayDate);

    return Container(
      padding: const EdgeInsetsDirectional.all(MqSpacing.space4),
      decoration: BoxDecoration(
        // Plain content-card surface — only the date label and the
        // "Change" action below keep the red/pink accent; the card
        // itself no longer carries a red tint or border.
        color: dark
            ? Color.alphaBlend(
                Colors.white.withValues(alpha: 0.06),
                MqColors.charcoal800,
              )
            : Colors.white,
        borderRadius: BorderRadius.circular(MqSpacing.radiusXl),
        border: Border.all(
          color: dark ? Colors.white.withAlpha(20) : MqColors.sand200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateText.toUpperCase(),
            style: context.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: dark ? MqColors.brightRed : MqColors.red,
            ),
          ),
          const SizedBox(height: MqSpacing.space1),
          Text(
            selected == null ? l10n.openDay_pickInterest : selected!.name,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : MqColors.contentPrimary,
            ),
          ),
          const SizedBox(height: MqSpacing.space1),
          Text(
            selected == null
                ? l10n.openDay_chooseBachelorFilter
                : l10n.openDay_showingMatchedSessions,
            style: context.textTheme.bodySmall?.copyWith(
              color: dark
                  ? Colors.white.withValues(alpha: 0.78)
                  : MqColors.contentSecondary,
            ),
          ),
          const SizedBox(height: MqSpacing.space3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => BachelorPickerSheet.show(context),
              style: TextButton.styleFrom(
                foregroundColor: dark ? MqColors.brightRed : MqColors.red,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MqSpacing.space3,
                  vertical: MqSpacing.space1,
                ),
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(
                selected == null
                    ? l10n.openDay_chooseInterest
                    : l10n.openDay_changeInterest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prominent, tinted section header band that separates the "Matched to your
/// degree" feed from the "Open to all visitors" feed.
///
/// [primary] gives the band the Macquarie-red identity (the highlighted
/// degree section); the non-primary variant uses a quiet neutral tint so it
/// reads as clearly secondary. An icon chip on the leading edge reinforces
/// the meaning of each group at a glance.
class _SessionSectionHeader extends StatelessWidget {
  const _SessionSectionHeader({
    required this.label,
    required this.icon,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;

    final background = primary
        ? (dark ? MqColors.red.withAlpha(48) : MqColors.red.withAlpha(20))
        : (dark
              ? Colors.white.withValues(alpha: 0.06)
              : MqColors.charcoal800.withValues(alpha: 0.05));
    final borderColor = primary
        ? MqColors.red.withValues(alpha: dark ? 0.55 : 0.30)
        : (dark
              ? Colors.white.withValues(alpha: 0.10)
              : MqColors.charcoal800.withValues(alpha: 0.10));
    final labelColor = primary
        ? (dark ? Colors.white : MqColors.red)
        : (dark
              ? Colors.white.withValues(alpha: 0.82)
              : MqColors.contentSecondary);
    final iconBg = primary
        ? MqColors.red
        : (dark ? Colors.white.withValues(alpha: 0.18) : MqColors.charcoal600);

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(MqSpacing.space3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MqSpacing.radiusLg),
        border: Border.all(color: borderColor, width: primary ? 1.0 : 0.6),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: MqSpacing.space3),
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBlockHeader extends StatelessWidget {
  const _TimeBlockHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: MqSpacing.space4,
        bottom: MqSpacing.space2,
        start: MqSpacing.space1,
      ),
      child: Text(
        label.toUpperCase(),
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: dark ? MqColors.brightRed : MqColors.red,
        ),
      ),
    );
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event});

  final OpenDayEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final timeRange = OpenDayTime.formatTimeRange(
      event.startTime,
      event.endTime,
    );
    final isSaved =
        ref
            .watch(settingsControllerProvider)
            .value
            ?.isOpenDayEventSaved(event.id) ??
        false;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Lift the tile slightly off the charcoal800 scaffold in dark mode —
        // an identical fill left card boundaries defined only by a 5% border.
        color: dark
            ? Color.alphaBlend(
                Colors.white.withValues(alpha: 0.06),
                MqColors.charcoal800,
              )
            : Colors.white,
        borderRadius: BorderRadius.circular(MqSpacing.radiusXl),
        border: Border.all(
          color: dark ? Colors.white.withAlpha(20) : MqColors.sand200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MqSpacing.space4,
                MqSpacing.space3,
                MqSpacing.space2,
                MqSpacing.space3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : MqColors.contentPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$timeRange  ·  ${event.venueName}',
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
          ),
          // Save-to-"Your Day" toggle. Lightweight bookmark — the entire
          // itinerary feature is just this set of saved IDs.
          Semantics(
            button: true,
            label: isSaved
                ? l10n.openDay_removeFromMyDay
                : l10n.openDay_addToMyDay,
            child: MqTactileButton(
              onTap: () async {
                await ref
                    .read(settingsControllerProvider.notifier)
                    .toggleSavedOpenDayEvent(event.id);
                if (context.mounted) {
                  context.showSnackBar(
                    isSaved
                        ? l10n.openDay_removedFromMyDay
                        : l10n.openDay_savedToMyDay,
                  );
                }
              },
              borderRadius: MqSpacing.radiusXl,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MqSpacing.space2,
                  vertical: MqSpacing.space3,
                ),
                child: Icon(
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 24,
                  color: dark ? MqColors.brightRed : MqColors.red,
                ),
              ),
            ),
          ),
          // Venue action: jumps straight to this venue on the Campus Map.
          Semantics(
            button: true,
            label: l10n.openDay_directionsTo(event.venueName),
            child: MqTactileButton(
              onTap: () => openEventVenueOnMap(context, event),
              borderRadius: MqSpacing.radiusXl,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MqSpacing.space4,
                  vertical: MqSpacing.space3,
                ),
                child: Icon(
                  Icons.directions_rounded,
                  size: 24,
                  color: dark ? MqColors.brightRed : MqColors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyEventsState extends StatelessWidget {
  const _EmptyEventsState({required this.hasSelection});

  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(MqSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 48,
            color: context.isDarkMode
                ? MqColors.slate500
                : MqColors.charcoal600,
          ),
          const SizedBox(height: MqSpacing.space3),
          Text(
            hasSelection
                ? AppLocalizations.of(context)!.openDay_noEventsForSelection
                : AppLocalizations.of(context)!.openDay_noEventsNoneSelected,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
