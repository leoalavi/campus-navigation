import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/open_day/presentation/widgets/open_day_home_card.dart';
import 'package:mq_journey/features/open_day/presentation/widgets/open_day_home_sections.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/features/transit/domain/entities/metro_departure.dart';
import 'package:mq_journey/features/transit/presentation/providers/tfnsw_provider.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';
import 'package:mq_journey/shared/widgets/mq_tactile_button.dart';

/// Home screen for the MQ Navigation app.
///
/// Structure (top → bottom):
///   1. Hero — official MQ shield logo + welcome copy + CTA
///   2. Metro Countdown glanceable card (configurable from Settings)
///   3. Quick Access — 2 featured tiles + 3 supporting tiles
///
/// Removed intentionally:
///   - The dedicated top app-bar / branded header. The hero now carries
///     the brand identity via the official MQ shield logo, eliminating
///     vertical clutter and the prior "icon + wordmark" duplication.
///   - "Transport" Quick Access item — the Metro Countdown card already
///     covers the same intent in a more glanceable form.
///   - "Next Class" card and "Events" tile — outside the navigation scope.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const _backgroundAsset = 'assets/images/campus_background.jpg';
  static const _logoAsset = 'assets/images/mq_logo.png';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDarkMode;
    final preferences =
        ref.watch(settingsControllerProvider).value ?? const UserPreferences();
    final hapticsEnabled = preferences.hapticsEnabled;
    final metroDepartures = ref.watch(tfnswMetroProvider);

    return Scaffold(
      backgroundColor: dark ? MqColors.charcoal800 : MqColors.alabaster,
      body: Stack(
        children: [
          _CampusBackground(asset: _backgroundAsset, isDark: dark),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MqColors.black.withValues(alpha: dark ? 0.34 : 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          if (dark)
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              height: 360,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1.2),
                      radius: 1.1,
                      colors: [MqColors.red.withAlpha(38), Colors.transparent],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      MqSpacing.space5,
                      MqSpacing.space8,
                      MqSpacing.space5,
                      MqSpacing.space12,
                    ),
                    child: Column(
                      children: [
                        // ── A. Study-interest group ──────────────────────
                        // 1. QR-first CTA hero.
                        const _HeroSection(logoAsset: _logoAsset),
                        const SizedBox(height: MqSpacing.space5),
                        // 2. Study Interest card (onboarding CTA before a
                        //    choice, compact preview after).
                        const OpenDayHomeCard(),
                        // 3–4. Coming Up Next → Suggested Stops, kept together
                        //    as the interest-driven cluster. Self-hiding until
                        //    a study interest is chosen.
                        const OpenDayPersonalisedSections(),
                        const SizedBox(height: MqSpacing.space4),
                        // ── B. Personal saved flow ───────────────────────
                        // 5. Your Day — independent of interest selection, so
                        //    it always appears (with an empty state) once the
                        //    Open Day dataset is available.
                        const OpenDayYourDayCard(),
                        const SizedBox(height: MqSpacing.space6),
                        // ── C. Support ───────────────────────────────────
                        // 6. Next Metro (commute card).
                        _MetroCountdownCard(
                          commuteMode: preferences.commuteMode,
                          favoriteRoute: preferences.favoriteRoute,
                          metroDepartures: metroDepartures,
                          // Deep-link straight to the Commute Preferences
                          // section of Settings, not the top of the page.
                          onConfigureTap: () => context.goNamed(
                            RouteNames.settings,
                            queryParameters: {'section': 'commute'},
                          ),
                          onRefreshTap: () =>
                              ref.invalidate(tfnswMetroProvider),
                        ),
                        const SizedBox(height: MqSpacing.space6),
                        // 7. Quick Access — lowest-priority legacy campus
                        //    shortcuts.
                        _QuickAccessSection(
                          hapticsEnabled: hapticsEnabled,
                          onTapCategory: (query) {
                            // Riverpod state is global; AppShell preserves
                            // MapPage so we must update the controller
                            // imperatively before switching tabs.
                            ref
                                .read(mapControllerProvider.notifier)
                                .updateSearchQuery(query);
                            context.goNamed(RouteNames.map);
                          },
                        ),
                        const SizedBox(height: MqSpacing.space6),
                        // 8. Privacy note — a quiet, low-priority informational
                        //    line at the very bottom (no longer competing with
                        //    the hero CTA up top).
                        const _PrivacyStrip(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------- //
// METRO COUNTDOWN CARD                                                       //
// -------------------------------------------------------------------------- //

/// Compact, glanceable card showing the next departure for the user's
/// configured commute line. If no commute has been set up yet, the card
/// shows a friendly "Set up your commute" CTA that routes to Settings.
class _MetroCountdownCard extends StatelessWidget {
  const _MetroCountdownCard({
    required this.commuteMode,
    required this.favoriteRoute,
    required this.metroDepartures,
    required this.onConfigureTap,
    required this.onRefreshTap,
  });

  final String commuteMode;
  final String favoriteRoute;
  final AsyncValue<List<MetroDeparture>> metroDepartures;
  final VoidCallback onConfigureTap;
  final VoidCallback onRefreshTap;

  bool get _isConfigured => commuteMode != 'none';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;

    final surface = dark
        ? MqColors.charcoal800.withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.94);
    final border = dark
        ? Colors.white.withValues(alpha: 0.08)
        : MqColors.charcoal800.withValues(alpha: 0.06);
    const accent = MqColors.brightRed;
    final titleColor = dark ? Colors.white : MqColors.black;
    final subtitleColor = dark ? Colors.white : MqColors.black;

    final modeIcon = switch (commuteMode) {
      'metro' => Icons.directions_subway,
      'bus' => Icons.directions_bus,
      'train' => Icons.directions_train,
      _ => Icons.directions_transit_outlined,
    };
    final modeLabel = switch (commuteMode) {
      'metro' => l10n.commuteModeMetro,
      'bus' => l10n.commuteModeBus,
      'train' => l10n.commuteModeTrain,
      _ => l10n.commuteModeNotSet,
    };

    Widget content;
    if (!_isConfigured) {
      content = _EmptyState(
        accent: accent,
        subtitleColor: subtitleColor,
        titleColor: titleColor,
      );
    } else {
      content = metroDepartures.when(
        data: (list) => _DepartureBody(
          accent: accent,
          favoriteRoute: favoriteRoute,
          modeIcon: modeIcon,
          modeLabel: modeLabel,
          departures: list,
          subtitleColor: subtitleColor,
          titleColor: titleColor,
        ),
        loading: () => _LoadingBody(subtitleColor: subtitleColor),
        error: (_, _) => _ErrorBody(subtitleColor: subtitleColor),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(MqSpacing.radiusXl),
        border: Border.all(color: border, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: MqColors.charcoal800.withValues(alpha: dark ? 0.30 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsetsDirectional.all(MqSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: MqColors.red,
              shape: BoxShape.circle,
            ),
            child: Icon(modeIcon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: MqSpacing.space3),
          Expanded(child: content),
          _MetroCardIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: l10n.refreshDepartures,
            onTap: onRefreshTap,
          ),
          _MetroCardIconButton(
            icon: Icons.tune_rounded,
            semanticLabel: l10n.configureCommute,
            onTap: onConfigureTap,
          ),
        ],
      ),
    );
  }
}

class _MetroCardIconButton extends StatelessWidget {
  const _MetroCardIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    return IconButton(
      icon: Icon(icon),
      color: dark ? Colors.white : MqColors.contentTertiary,
      iconSize: 20,
      onPressed: onTap,
      tooltip: semanticLabel,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.accent,
    required this.subtitleColor,
    required this.titleColor,
  });

  final Color accent;
  final Color subtitleColor;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.homeNextMetroLabel,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        const SizedBox(height: MqSpacing.space1),
        Text(
          l10n.commuteModeNotSet,
          style: context.textTheme.bodySmall?.copyWith(color: subtitleColor),
        ),
      ],
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.subtitleColor});

  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: subtitleColor,
          ),
        ),
        const SizedBox(width: MqSpacing.space2),
        Text(
          l10n.loading,
          style: context.textTheme.bodySmall?.copyWith(color: subtitleColor),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.subtitleColor});

  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.homeNextMetroEmpty,
      style: context.textTheme.bodySmall?.copyWith(color: subtitleColor),
    );
  }
}

class _DepartureBody extends StatelessWidget {
  const _DepartureBody({
    required this.accent,
    required this.favoriteRoute,
    required this.modeIcon,
    required this.modeLabel,
    required this.departures,
    required this.subtitleColor,
    required this.titleColor,
  });

  final Color accent;
  final String favoriteRoute;
  final IconData modeIcon;
  final String modeLabel;
  final List<MetroDeparture> departures;
  final Color subtitleColor;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final next = departures.isEmpty ? null : departures.first;
    // Prefer the line the API actually reports for *this* departure over the
    // saved preference string — if the server's route filter ever falls back
    // to an unfiltered list, echoing the saved preference here would pair it
    // with a destination/line that doesn't really match.
    final routeLabel = next != null && next.line.trim().isNotEmpty
        ? next.line.trim()
        : favoriteRoute.trim();
    final routeSuffix = routeLabel.isEmpty ? '' : ' • $routeLabel';

    final title = next == null
        ? l10n.homeNextMetroLabel
        : _formatCountdown(l10n, next.minutesUntilDeparture);
    final subtitle = next == null
        ? l10n.homeNextMetroEmpty
        : '${next.destination}$routeSuffix';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              '$modeLabel  ·  ',
              style: context.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            Flexible(
              child: Text(
                next == null ? '—' : l10n.homeNextMetroLabel,
                style: context.textTheme.labelSmall?.copyWith(
                  color: subtitleColor,
                  letterSpacing: 0.6,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: titleColor,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodySmall?.copyWith(color: subtitleColor),
        ),
      ],
    );
  }
}

/// Formats a departure countdown for display. The TfNSW proxy returns the
/// minutes until the next service; outside peak/service hours that can be a
/// couple of hours away, and "439 min" is hard to parse at a glance — so once
/// it crosses an hour we show "7h 19m" (or "7h" on the exact hour) instead.
String _formatCountdown(AppLocalizations l10n, int minutes) {
  if (minutes < 60) return l10n.minutesShort(minutes);
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0
      ? l10n.hoursShort(hours)
      : l10n.hoursMinutesShort(hours, remainder);
}

// -------------------------------------------------------------------------- //
// CAMPUS BACKGROUND                                                          //
// -------------------------------------------------------------------------- //

class _CampusBackground extends StatelessWidget {
  const _CampusBackground({required this.asset, required this.isDark});

  final String asset;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 4.8, sigmaY: 4.8),
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.803,
                0.179,
                0.018,
                0,
                0,
                0.053,
                0.929,
                0.018,
                0,
                0,
                0.053,
                0.179,
                0.768,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Colors.white),
              ),
            ),
          ),
          Container(color: Colors.white.withValues(alpha: 0.08)),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------- //
// WELCOME + CTA HERO                                                         //
// -------------------------------------------------------------------------- //

/// Hero block. Lays out the official MQ shield logo to the left of the
/// welcome copy so the brand identity travels with the message — replacing
/// the prior top branding bar — while the CTA button remains full-width
/// below for one-handed reachability.
class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.logoAsset});

  final String logoAsset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;

    final titleColor = dark ? Colors.white : MqColors.black;
    final subtitleColor = dark ? Colors.white : MqColors.black;
    const ctaColor = MqColors.red;
    final heroTextShadow = dark
        ? [
            Shadow(
              blurRadius: 20,
              color: MqColors.charcoal800.withValues(alpha: 0.62),
              offset: const Offset(0, 2),
            ),
            Shadow(
              blurRadius: 14,
              color: Colors.white.withValues(alpha: 0.28),
              offset: Offset.zero,
            ),
          ]
        : [
            Shadow(
              blurRadius: 18,
              color: MqColors.black.withValues(alpha: 0.42),
              offset: const Offset(0, 2),
            ),
            Shadow(
              blurRadius: 6,
              color: MqColors.black.withValues(alpha: 0.22),
              offset: Offset.zero,
            ),
          ];
    final subtitleTextShadow = dark
        ? [
            Shadow(
              blurRadius: 22,
              color: MqColors.charcoal800.withValues(alpha: 0.68),
              offset: const Offset(0, 2),
            ),
            Shadow(
              blurRadius: 12,
              color: Colors.white.withValues(alpha: 0.34),
              offset: Offset.zero,
            ),
          ]
        : [
            Shadow(
              blurRadius: 18,
              color: MqColors.black.withValues(alpha: 0.46),
              offset: const Offset(0, 2),
            ),
            Shadow(
              blurRadius: 6,
              color: MqColors.black.withValues(alpha: 0.24),
              offset: Offset.zero,
            ),
          ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          // Logo + welcome copy. The logo is sized to span the full
          // height of the two-line text block so the brand mark feels
          // like a true hero anchor — not an afterthought icon.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Aspect-ratio-aware: the shield asset is taller than wide,
                // so we let height drive layout and let width fall out
                // naturally via `BoxFit.contain`. 100px gives the logo
                // visual mass equal to title + subtitle stacked.
                _MqShieldLogo(asset: logoAsset, size: 100),
                const SizedBox(width: MqSpacing.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.home_welcomeTitle,
                        style: context.textTheme.headlineLarge?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.4,
                          color: titleColor,
                          shadows: heroTextShadow,
                        ),
                      ),
                      const SizedBox(height: MqSpacing.space1),
                      Text(
                        l10n.home_welcomeSubtitle,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: subtitleColor,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: dark ? FontWeight.w700 : FontWeight.w600,
                          shadows: subtitleTextShadow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MqSpacing.space5),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => context.pushNamed(RouteNames.scan),
              style: FilledButton.styleFrom(
                backgroundColor: ctaColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MqSpacing.space6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MqSpacing.radiusXl),
                ),
                elevation: 2,
              ),
              icon: const Icon(
                Icons.qr_code_scanner_rounded,
                size: MqSpacing.iconMd,
              ),
              label: Text(
                l10n.home_scanQrCta,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the official MQ shield logo at a given size, with a graceful
/// fallback shield in case the asset isn't bundled. The fallback keeps
/// the layout stable during initial onboarding of the asset and on any
/// device where the asset failed to load.
class _MqShieldLogo extends StatelessWidget {
  const _MqShieldLogo({required this.asset, required this.size});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.macquarieUniversity,
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => _LogoFallback(size: size),
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    // Pentagon-ish red shield placeholder — preserves visual mass and
    // brand color until the official asset ships.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MqColors.red,
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [
          BoxShadow(
            color: MqColors.red.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.school_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------- //
// PRIVACY / INSTANT-ACCESS STRIP                                             //
// -------------------------------------------------------------------------- //

/// Quiet privacy note shown at the very bottom of Home. Text color alone
/// can't guarantee contrast here — like [_SectionHeader] above it, this sits
/// directly on the blurred campus photo background, not a plain surface, so
/// it gets its own small pill chip rather than floating loose. Kept low-key
/// versus [_SectionHeader] (footnote-sized, regular weight, no shadow) so it
/// still reads as an informational aside, not a section title or CTA.
class _PrivacyStrip extends StatelessWidget {
  const _PrivacyStrip();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final color = dark
        ? Colors.white.withValues(alpha: 0.85)
        : MqColors.contentSecondary;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark
              ? MqColors.black.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : MqColors.black.withValues(alpha: 0.14),
            width: 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: MqSpacing.space3,
            vertical: MqSpacing.space1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: color),
              const SizedBox(width: MqSpacing.space1),
              Flexible(
                child: Text(
                  l10n.openDay_privacyStrip,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(color: color),
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
// QUICK ACCESS                                                               //
// -------------------------------------------------------------------------- //

/// Quick Access bento layout, post-Transport removal:
///   Row 1 — two equal featured tiles: Student Services · Faculty
///   Row 2 — three supporting compact tiles: Parking · Campus Hub · Food & Drink
///
/// Transport is intentionally absent — the Metro Countdown card above
/// already covers the same intent in a more glanceable form, so a
/// duplicate Quick Access tile would only add noise.
class _QuickAccessSection extends StatelessWidget {
  const _QuickAccessSection({
    required this.hapticsEnabled,
    required this.onTapCategory,
  });

  final bool hapticsEnabled;
  final void Function(String searchQuery) onTapCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.home_quickAccess),
        // Two featured tiles, equal width, equal hierarchy.
        // Each tap dispatches a query that matches a tag we apply
        // in `assets/data/buildings.json` — see that file's tagging
        // convention for the canonical mapping.
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BentoHeroCard(
                  hapticsEnabled: hapticsEnabled,
                  icon: Icons.support_agent,
                  isDark: dark,
                  label: l10n.home_studentServices,
                  onTap: () => onTapCategory('student services'),
                ),
              ),
              const SizedBox(width: MqSpacing.space4),
              Expanded(
                child: _BentoHeroCard(
                  hapticsEnabled: hapticsEnabled,
                  icon: Icons.school,
                  isDark: dark,
                  label: l10n.home_faculty,
                  onTap: () => onTapCategory('faculty'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MqSpacing.space4),
        // Three supporting tiles, lower visual weight.
        _TertiaryQuickRow(
          hapticsEnabled: hapticsEnabled,
          items: [
            _QuickAccessItem(
              icon: Icons.local_parking,
              label: l10n.home_parking,
              searchQuery: 'parking',
            ),
            _QuickAccessItem(
              icon: Icons.account_balance,
              label: l10n.home_campusHub,
              searchQuery: 'campus hub',
            ),
            _QuickAccessItem(
              icon: Icons.restaurant,
              label: l10n.home_foodDrink,
              searchQuery: 'food',
            ),
          ],
          onTapCategory: onTapCategory,
        ),
      ],
    );
  }
}

class _QuickAccessItem {
  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.searchQuery,
  });

  final IconData icon;
  final String label;
  final String searchQuery;
}

/// Prominent section header. Sized + coloured to anchor each section
/// over the photo background.
///
/// Design notes:
///   * **Black, not red.** The prior red-on-photo tint sat in the same
///     hue family as the warm campus image and lost contrast. Pure
///     black/white maximises legibility on every photo crop.
///   * **20pt, weight 800**: a real titleLarge-grade hit, so the eye
///     reads "Quick Access" before any of the tiles below.
///   * **Subtle white halo** on light mode, deep black halo on dark
///     mode: gives the glyphs a bit of separation from a busy photo
///     without looking like a hard outline.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: MqSpacing.space1,
        bottom: MqSpacing.space4,
      ),
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
            MqSpacing.space2,
            MqSpacing.space1,
            MqSpacing.space2,
            MqSpacing.space1,
          ),
          child: Text(
            title.toUpperCase(),
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              fontSize: 20,
              height: 1.1,
              color: dark ? Colors.white : MqColors.charcoal800,
              shadows: dark
                  ? [
                      // Strong dark lift + soft white glow for high-contrast clouds.
                      Shadow(
                        blurRadius: 18,
                        color: MqColors.charcoal800.withValues(alpha: 0.65),
                        offset: const Offset(0, 2),
                      ),
                      Shadow(
                        blurRadius: 10,
                        color: Colors.white.withValues(alpha: 0.24),
                        offset: Offset.zero,
                      ),
                    ]
                  : [
                      Shadow(
                        blurRadius: 14,
                        color: MqColors.black.withValues(alpha: 0.42),
                        offset: const Offset(0, 1),
                      ),
                      Shadow(
                        blurRadius: 4,
                        color: MqColors.black.withValues(alpha: 0.24),
                        offset: Offset.zero,
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BentoHeroCard extends StatelessWidget {
  const _BentoHeroCard({
    required this.hapticsEnabled,
    required this.icon,
    required this.isDark,
    required this.label,
    required this.onTap,
  });

  final bool hapticsEnabled;
  final IconData icon;
  final bool isDark;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelParts = label.split(' & ');
    final heroLabel = labelParts.length > 1
        ? '${labelParts[0]} &\n${labelParts[1]}'
        : label;

    return Semantics(
      button: true,
      label: label,
      child: MqTactileButton(
        hapticsEnabled: hapticsEnabled,
        onTap: onTap,
        borderRadius: MqSpacing.radiusXl,
        child: Container(
          decoration: BoxDecoration(
            // Slightly stronger surface alpha than v7 so the card
            // reads cleanly over high-contrast photo crops, paired
            // with a soft drop shadow for a more premium elevation.
            color: isDark
                ? MqColors.charcoal800.withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(MqSpacing.radiusXl),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : MqColors.charcoal800.withValues(alpha: 0.06),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: MqColors.charcoal800.withValues(
                  alpha: isDark ? 0.30 : 0.10,
                ),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsetsDirectional.all(MqSpacing.space6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsetsDirectional.all(MqSpacing.space3),
                decoration: const BoxDecoration(
                  color: MqColors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: MqSpacing.space4),
              Text(
                heroLabel,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: isDark ? Colors.white : MqColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3-across compact row — replaces the 4-item wrap grid so the
/// tertiary tiles feel intentional after Events was removed.
class _TertiaryQuickRow extends StatelessWidget {
  const _TertiaryQuickRow({
    required this.hapticsEnabled,
    required this.items,
    required this.onTapCategory,
  });

  final bool hapticsEnabled;
  final List<_QuickAccessItem> items;
  final void Function(String searchQuery) onTapCategory;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0) const SizedBox(width: MqSpacing.space3),
            Expanded(
              child: Semantics(
                button: true,
                label: items[i].label,
                child: MqTactileButton(
                  hapticsEnabled: hapticsEnabled,
                  onTap: () => onTapCategory(items[i].searchQuery),
                  borderRadius: MqSpacing.radiusLg,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? MqColors.charcoal800.withValues(alpha: 0.94)
                          : Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(MqSpacing.radiusLg),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : MqColors.charcoal800.withValues(alpha: 0.06),
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MqColors.charcoal800.withValues(
                            alpha: isDark ? 0.25 : 0.08,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: MqSpacing.space3,
                      vertical: MqSpacing.space4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          items[i].icon,
                          size: MqSpacing.iconMd,
                          color: MqColors.red,
                        ),
                        const SizedBox(height: MqSpacing.space2),
                        Text(
                          items[i].label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : MqColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
