import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_animations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/nav_instruction.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';

/// Floating bottom sheet displaying routing instructions and status.
///
/// Reacts dynamically to state changes during active navigation (e.g., showing
/// the next immediate turn, updating distance/ETA, or displaying the arrival
/// celebration card).
class RoutePanel extends StatefulWidget {
  const RoutePanel({
    super.key,
    required this.selectedBuilding,
    required this.route,
    required this.currentLocation,
    required this.travelMode,
    required this.supportedTravelModes,
    required this.isLoading,
    required this.isNavigating,
    required this.hasArrived,
    required this.onLoadRoute,
    required this.onClearRoute,
    required this.onClearSelection,
    required this.onTravelModeChanged,
    required this.onStartNavigation,
    required this.onStopNavigation,
    required this.onDismissArrival,
  });

  final Building? selectedBuilding;
  final MapRoute? route;
  final LocationSample? currentLocation;
  final TravelMode travelMode;
  final List<TravelMode> supportedTravelModes;
  final bool isLoading;
  final bool isNavigating;
  final bool hasArrived;
  final Future<void> Function() onLoadRoute;
  final VoidCallback onClearRoute;
  final VoidCallback onClearSelection;
  final ValueChanged<TravelMode> onTravelModeChanged;
  final VoidCallback onStartNavigation;
  final VoidCallback onStopNavigation;
  final VoidCallback onDismissArrival;

  @override
  State<RoutePanel> createState() => _RoutePanelState();
}

class _RoutePanelState extends State<RoutePanel> {
  bool _stepsExpanded = false;

  /// Tracks whether the panel is collapsed to a compact "peek" bar so the
  /// user can see the map while navigation is still active. Only used
  /// during navigation — outside of navigation the panel is always
  /// expanded because the user needs to see the action buttons.
  ///
  /// **Important UX contract**: minimising does NOT stop navigation. The
  /// only way to stop navigation is the explicit "Stop navigation" button
  /// inside the expanded panel.
  bool _minimized = false;

  @override
  void didUpdateWidget(covariant RoutePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always re-expand when navigation transitions on/off so a stale
    // minimised state from a previous trip doesn't hide the action
    // buttons the user now needs.
    if (oldWidget.isNavigating != widget.isNavigating) {
      _minimized = false;
    }
  }

  void _toggleMinimized() {
    setState(() => _minimized = !_minimized);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;

    if (widget.selectedBuilding == null) {
      return const SizedBox.shrink();
    }

    // Arrival celebration
    if (widget.hasArrived) {
      return _ArrivalCard(
        buildingName: widget.selectedBuilding?.name ?? '',
        arrivedLabel: l10n.youveArrived,
        doneLabel: l10n.done,
        onDismiss: widget.onDismissArrival,
        isDark: isDark,
      );
    }

    // Compact "peek" mode while navigating — shows just the next turn so
    // the user can see the map. A drag-up on the handle, a tap on it, or
    // the chevron all expand it back. The map's bottom anchors remain
    // stable because [MapShell] reserves a fixed band regardless of
    // panel height.
    if (widget.isNavigating && _minimized) {
      return _MinimizedNavBar(
        nextInstructionText: widget.route?.instructions.isNotEmpty == true
            ? widget.route!.instructions.first.text
            : widget.selectedBuilding!.name,
        isDark: isDark,
        onExpand: _toggleMinimized,
      );
    }

    return GlassSurface(
      variant: GlassVariant.content,
      borderRadius: BorderRadius.circular(MqSpacing.radiusXl),
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : MqColors.charcoal800.withValues(alpha: 0.06),
      borderWidth: 0.6,
      padding: const EdgeInsets.all(MqSpacing.space6),
      boxShadow: [
        BoxShadow(
          color: MqColors.charcoal800.withValues(alpha: isDark ? 0.30 : 0.10),
          blurRadius: 18,
          offset: const Offset(0, -6),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar — interactive when navigating: a downward
            // drag or a tap collapses the panel to the compact bar
            // so the user can see the map without stopping nav.
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.isNavigating ? _toggleMinimized : null,
                onVerticalDragEnd: widget.isNavigating
                    ? (details) {
                        // Positive Y velocity = swipe down → minimise.
                        if (details.primaryVelocity != null &&
                            details.primaryVelocity! > 120) {
                          setState(() => _minimized = true);
                        }
                      }
                    : null,
                child: Padding(
                  // Generous touch padding so the small visual handle
                  // becomes a comfortable drag/tap target.
                  padding: const EdgeInsets.symmetric(
                    horizontal: MqSpacing.space8,
                    vertical: MqSpacing.space2,
                  ),
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : MqColors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: MqSpacing.space6),

            // Building name + close button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedBuilding!.name,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: isDark
                                  ? Colors.white
                                  : MqColors.contentPrimary,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: MqSpacing.space1),
                      Row(
                        children: [
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                text: '${l10n.buildingCode}: ',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : MqColors.contentTertiary,
                                    ),
                                children: [
                                  TextSpan(
                                    text: widget.selectedBuilding!.code,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : MqColors.contentPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.selectedBuilding!.category !=
                              BuildingCategory.other) ...[
                            const SizedBox(width: MqSpacing.space2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MqSpacing.space3,
                                vertical: MqSpacing.space1,
                              ),
                              decoration: BoxDecoration(
                                color: MqColors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  MqSpacing.radiusFull,
                                ),
                              ),
                              child: Text(
                                widget.selectedBuilding!.category.name
                                    .toUpperCase(),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: MqColors.red,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Close / minimise affordance.
                //
                // **During navigation**: this now MINIMISES the panel
                // to the compact peek bar instead of stopping
                // navigation. The user previously had no way to see
                // the map without ending their trip — the X was a
                // hidden tripwire. Stopping nav is now an explicit
                // dedicated action ("Stop navigation" button below).
                //
                // **Outside navigation**: still clears the building
                // selection as before.
                IconButton(
                  icon: Icon(
                    widget.isNavigating ? Icons.expand_more : Icons.close,
                    size: MqSpacing.iconMd,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : MqColors.contentTertiary,
                  ),
                  tooltip: widget.isNavigating
                      ? l10n.routePanelMinimize
                      : l10n.clear,
                  onPressed: widget.isNavigating
                      ? _toggleMinimized
                      : widget.onClearSelection,
                ),
              ],
            ),

            // Route info row (when route is loaded)
            if (widget.route != null) ...[
              const SizedBox(height: MqSpacing.space4),
              _RouteInfoRow(route: widget.route!, l10n: l10n, isDark: isDark),
            ],

            // Travel mode selector (hidden during navigation)
            if (!widget.isNavigating) ...[
              const SizedBox(height: MqSpacing.space4),
              _TravelModePills(
                supportedTravelModes: widget.supportedTravelModes,
                travelMode: widget.travelMode,
                isDark: isDark,
                l10n: l10n,
                onChanged: widget.onTravelModeChanged,
              ),
            ],

            // Next instruction (during navigation)
            if (widget.isNavigating &&
                widget.route != null &&
                widget.route!.instructions.isNotEmpty) ...[
              const SizedBox(height: MqSpacing.space4),
              _NextInstructionCard(
                instruction: widget.route!.instructions.first,
                isDark: isDark,
              ),
            ],

            // Expandable steps
            if (widget.route != null &&
                widget.route!.instructions.isNotEmpty) ...[
              const SizedBox(height: MqSpacing.space2),
              _ExpandableStepList(
                instructions: widget.route!.instructions,
                isNavigating: widget.isNavigating,
                isExpanded: _stepsExpanded,
                isDark: isDark,
                onToggle: () =>
                    setState(() => _stepsExpanded = !_stepsExpanded),
              ),
            ],

            const SizedBox(height: MqSpacing.space4),

            // Action buttons
            if (widget.route != null) ...[
              if (widget.isNavigating)
                _GlassOutlinedButton(
                  label: l10n.stopNavigation,
                  isDark: isDark,
                  onPressed: widget.onStopNavigation,
                )
              else ...[
                _BrandActionButton(
                  label: l10n.startTurnByTurn,
                  icon: Icons.double_arrow_rounded,
                  onPressed: widget.onStartNavigation,
                ),
                const SizedBox(height: MqSpacing.space2),
                // Action row — Clear only.
                //
                // Prior iterations of this row stacked optional icon
                // buttons here (Street View, Compass Mode, Open in
                // Google Maps). The earlier two were removed during
                // the first cleanup pass for being either redundant
                // (Open in Google Maps when the user is already in
                // Google Maps mode) or unlocalised/experimental
                // (Compass Mode). Street View is now also removed:
                // tappable peeks at the destination are a "weak"
                // nice-to-have, and shipping them alongside Clear
                // creates the same unlabelled-icon ambiguity the
                // user called out. The final route panel is now a
                // single primary action (Clear) with no mystery
                // controls.
                _GlassOutlinedButton(
                  label: l10n.clear,
                  isDark: isDark,
                  onPressed: widget.onClearRoute,
                ),
              ],
            ] else ...[
              // No route yet — show "Get Directions" button
              _BrandActionButton(
                label: widget.isLoading
                    ? l10n.loadingRoute
                    : _directionsLabel(l10n),
                icon: Icons.double_arrow_rounded,
                isLoading: widget.isLoading,
                onPressed: widget.selectedBuilding == null
                    ? null
                    : () => widget.onLoadRoute(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _directionsLabel(AppLocalizations l10n) {
    return switch (widget.travelMode) {
      TravelMode.walk => l10n.walkingDirections,
      TravelMode.drive => l10n.drive,
      TravelMode.bike => l10n.bike,
      TravelMode.transit => l10n.transit,
    };
  }
}

// ── Route info row (duration + distance) ───────────────────

class _RouteInfoRow extends StatelessWidget {
  const _RouteInfoRow({
    required this.route,
    required this.l10n,
    required this.isDark,
  });

  final MapRoute route;
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final duration = _fmtDuration(route.durationSeconds, l10n);
    final distance = _fmtDistance(route.distanceMeters, l10n);

    return Row(
      children: [
        Icon(
          Icons.schedule,
          size: 18,
          color: isDark
              ? Colors.white.withValues(alpha: 0.5)
              : MqColors.contentTertiary,
        ),
        const SizedBox(width: MqSpacing.space2),
        Text(
          duration,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : MqColors.contentPrimary,
          ),
        ),
        const SizedBox(width: MqSpacing.space6),
        Icon(
          Icons.navigation_outlined,
          size: 18,
          color: isDark
              ? Colors.white.withValues(alpha: 0.5)
              : MqColors.contentTertiary,
        ),
        const SizedBox(width: MqSpacing.space2),
        Text(
          distance,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : MqColors.contentPrimary,
          ),
        ),
        const Spacer(),
        Text(
          '${l10n.eta} ${DateFormat('h:mm a').format(route.arrivalAt)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white : MqColors.contentTertiary,
          ),
        ),
      ],
    );
  }

  static String _fmtDuration(int totalSeconds, AppLocalizations l10n) {
    final m = (totalSeconds / 60).ceil().clamp(1, 999999);
    return m < 60
        ? l10n.durationMinutes(m)
        : l10n.durationHoursMinutes(m ~/ 60, m % 60);
  }

  static String _fmtDistance(int meters, AppLocalizations l10n) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} ${l10n.routeKilometersShort}';
    }
    return '$meters ${l10n.routeMetersShort}';
  }
}

// ── Travel mode pills ──────────────────────────────────────

class _TravelModePills extends StatelessWidget {
  const _TravelModePills({
    required this.travelMode,
    required this.supportedTravelModes,
    required this.isDark,
    required this.l10n,
    required this.onChanged,
  });

  final TravelMode travelMode;
  final List<TravelMode> supportedTravelModes;
  final bool isDark;
  final AppLocalizations l10n;
  final ValueChanged<TravelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: supportedTravelModes.map((mode) {
          final isSelected = mode == travelMode;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: MqSpacing.space2),
            child: Semantics(
              button: true,
              selected: isSelected,
              child: GestureDetector(
                onTap: () => onChanged(mode),
                child: AnimatedContainer(
                  duration: MqAnimations.normal,
                  constraints: const BoxConstraints(
                    minHeight: MqSpacing.minTapTarget,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MqSpacing.space4,
                    vertical: MqSpacing.space2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MqColors.red.withValues(alpha: 0.15)
                        : isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : MqColors.charcoal800.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
                    border: Border.all(
                      color: isSelected
                          ? MqColors.red.withValues(alpha: 0.4)
                          : isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : MqColors.charcoal800.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconFor(mode),
                        size: MqSpacing.iconSm,
                        color: isSelected
                            ? MqColors.red
                            : isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : MqColors.contentTertiary,
                      ),
                      const SizedBox(width: MqSpacing.space2),
                      Text(
                        _labelFor(mode),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? MqColors.red
                              : isDark
                              ? Colors.white
                              : MqColors.contentSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _iconFor(TravelMode mode) {
    return switch (mode) {
      TravelMode.walk => Icons.directions_walk,
      TravelMode.drive => Icons.directions_car,
      TravelMode.bike => Icons.directions_bike,
      TravelMode.transit => Icons.directions_transit,
    };
  }

  String _labelFor(TravelMode mode) {
    return switch (mode) {
      TravelMode.walk => l10n.walk,
      TravelMode.drive => l10n.drive,
      TravelMode.bike => l10n.bike,
      TravelMode.transit => l10n.transit,
    };
  }
}

// ── Next instruction card (during navigation) ──────────────

class _NextInstructionCard extends StatelessWidget {
  const _NextInstructionCard({required this.instruction, required this.isDark});

  final NavInstruction instruction;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MqSpacing.space3,
        vertical: MqSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? MqColors.navInstructionBgDark
            : MqColors.navInstructionBgLight,
        borderRadius: BorderRadius.circular(MqSpacing.radiusMd),
        border: Border.all(
          color: isDark
              ? MqColors.navInstructionBorderDark
              : MqColors.navInstructionBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            instruction.text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : MqColors.navInstructionTextLight,
            ),
          ),
          if (instruction.distanceMeters > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 2),
              child: Text(
                instruction.distanceMeters >= 1000
                    ? '${(instruction.distanceMeters / 1000).toStringAsFixed(1)} ${l10n.routeKilometersShort}'
                    : '${instruction.distanceMeters} ${l10n.routeMetersShort}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? Colors.white
                      : MqColors.navInstructionSubtextLight,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Expandable step list ───────────────────────────────────

class _ExpandableStepList extends StatelessWidget {
  const _ExpandableStepList({
    required this.instructions,
    required this.isNavigating,
    required this.isExpanded,
    required this.isDark,
    required this.onToggle,
  });

  final List<NavInstruction> instructions;
  final bool isNavigating;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(MqSpacing.radiusMd),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MqSpacing.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: MqSpacing.space1,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.stepsCount(instructions.length),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : MqColors.contentSecondary,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : MqColors.contentSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: instructions.length,
              itemBuilder: (context, index) {
                final step = instructions[index];
                final isFirst = index == 0 && isNavigating;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MqSpacing.space2,
                    vertical: MqSpacing.space2,
                  ),
                  decoration: isFirst
                      ? BoxDecoration(
                          color: isDark
                              ? MqColors.navInstructionBgDark
                              : MqColors.navInstructionBgLight,
                          borderRadius: BorderRadius.circular(
                            MqSpacing.radiusMd,
                          ),
                          border: Border.all(
                            color: isDark
                                ? MqColors.navInstructionBorderDark
                                : MqColors.navInstructionBorderLight,
                          ),
                        )
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : MqColors.sand100,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: MqSpacing.space2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.text,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (step.distanceMeters > 0)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  top: 2,
                                ),
                                child: Text(
                                  step.distanceMeters >= 1000
                                      ? '${(step.distanceMeters / 1000).toStringAsFixed(1)} ${l10n.routeKilometersShort}'
                                      : '${step.distanceMeters} ${l10n.routeMetersShort}',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: isDark
                                            ? Colors.white
                                            : MqColors.contentTertiary,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Action buttons ─────────────────────────────────────────

/// Full-width brand-red action button matching the reference design.
class _BrandActionButton extends StatelessWidget {
  const _BrandActionButton({
    required this.label,
    this.icon,
    this.isLoading = false,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: effectiveOnPressed == null
            ? MqColors.red.withValues(alpha: 0.5)
            : MqColors.red,
        borderRadius: BorderRadius.circular(MqSpacing.radiusLg),
        elevation: effectiveOnPressed == null ? 0 : 4,
        shadowColor: MqColors.red.withValues(alpha: 0.3),
        child: InkWell(
          onTap: effectiveOnPressed,
          borderRadius: BorderRadius.circular(MqSpacing.radiusLg),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: MqSpacing.minTapTarget + 8,
            ),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 22),
                        const SizedBox(width: MqSpacing.space2),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Outlined button with glass-like appearance.
class _GlassOutlinedButton extends StatelessWidget {
  const _GlassOutlinedButton({
    required this.label,
    required this.isDark,
    required this.onPressed,
  });

  final String label;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(MqSpacing.radiusMd),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: MqSpacing.minTapTarget,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: MqSpacing.space3,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : MqColors.black12,
              ),
              borderRadius: BorderRadius.circular(MqSpacing.radiusMd),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : MqColors.contentSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Minimised navigation bar ───────────────────────────────

/// Compact "peek" bar shown when the user has minimised the route panel
/// during active navigation. Surfaces just the next turn instruction so
/// the user can keep following directions while seeing the map. Tapping
/// or swiping up the bar re-expands the full panel.
class _MinimizedNavBar extends StatelessWidget {
  const _MinimizedNavBar({
    required this.nextInstructionText,
    required this.isDark,
    required this.onExpand,
  });

  final String nextInstructionText;
  final bool isDark;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: l10n.routePanelExpand,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onExpand,
        // Upward swipe restores the full panel — symmetric with the
        // downward swipe that minimised it.
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -120) {
            onExpand();
          }
        },
        child: GlassSurface(
          variant: GlassVariant.content,
          borderRadius: BorderRadius.circular(MqSpacing.radiusXl),
          borderColor: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : MqColors.charcoal800.withValues(alpha: 0.06),
          borderWidth: 0.6,
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.space5,
            vertical: MqSpacing.space3,
          ),
          boxShadow: [
            BoxShadow(
              color: MqColors.charcoal800.withValues(
                alpha: isDark ? 0.30 : 0.10,
              ),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
          child: Row(
            children: [
              const Icon(
                Icons.navigation_rounded,
                size: 22,
                color: MqColors.red,
              ),
              const SizedBox(width: MqSpacing.space3),
              Expanded(
                child: Text(
                  nextInstructionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : MqColors.contentPrimary,
                  ),
                ),
              ),
              const SizedBox(width: MqSpacing.space2),
              Icon(
                Icons.expand_less,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : MqColors.contentSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Arrival celebration ────────────────────────────────────

class _ArrivalCard extends StatelessWidget {
  const _ArrivalCard({
    required this.buildingName,
    required this.arrivedLabel,
    required this.doneLabel,
    required this.onDismiss,
    required this.isDark,
  });

  final String buildingName;
  final String arrivedLabel;
  final String doneLabel;
  final VoidCallback onDismiss;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      variant: GlassVariant.content,
      borderRadius: BorderRadius.circular(MqSpacing.radiusXl),
      color: isDark ? MqColors.arrivalBgDark : MqColors.arrivalBgLight,
      borderColor: isDark
          ? MqColors.arrivalBorderDark
          : MqColors.arrivalBorderLight,
      borderWidth: 0.6,
      padding: const EdgeInsets.all(MqSpacing.space6),
      boxShadow: [
        BoxShadow(
          color: MqColors.charcoal800.withValues(alpha: isDark ? 0.30 : 0.10),
          blurRadius: 18,
          offset: const Offset(0, -6),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: 40,
            color: isDark
                ? MqColors.arrivalIconDark
                : MqColors.arrivalIconLight,
          ),
          const SizedBox(height: MqSpacing.space3),
          Text(
            arrivedLabel,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : MqColors.arrivalTextLight,
            ),
          ),
          if (buildingName.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.space1),
            Text(
              buildingName,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : MqColors.arrivalSubtextLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: MqSpacing.space4),
          _BrandActionButton(label: doneLabel, onPressed: onDismiss),
        ],
      ),
    );
  }
}
