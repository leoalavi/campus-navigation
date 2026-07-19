import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/active_shell_branch_index_provider.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';

/// Persistent bottom navigation shell wrapping the main tab destinations.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navLabelColor = isDark ? Colors.white : Colors.black;

    // Publish the active branch index so branch-root pages that stay mounted
    // offstage (e.g. ScanPage, whose camera must pause when not visible) can
    // react to tab switches. Deferred to after this frame since providers
    // can't be written during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(activeShellBranchIndexProvider.notifier)
          .setIndex(navigationShell.currentIndex);
    });

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          // Detach the bar from the screen edges so it floats as a glass
          // "island" (the iOS 26 Liquid Glass tab-bar form) rather than a
          // flat, edge-to-edge bar.
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassSurface(
            variant: GlassVariant.control,
            borderRadius: BorderRadius.circular(36),
            child: NavigationBar(
              height: 64,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              // A bright translucent "lens" behind the selected destination.
              indicatorColor: Colors.white.withValues(alpha: 0.22),
              indicatorShape: const StadiumBorder(),
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                states,
              ) {
                return TextStyle(
                  color: navLabelColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                );
              }),
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) {
                // Navigate to the chosen branch. If the user taps the active tab,
                // the branch's navigation stack pops back to its root.
                //
                // The Journey (Campus Map) tab ALWAYS resets to its root: the
                // branch stack preserves whatever deep-linked URL it last had
                // (e.g. `/map?building=X` from a "View on Campus Map" or AR flow),
                // so without the reset, returning to Journey after visiting a
                // location re-restored that URL and force-reselected the stale
                // building. Tapping "Journey" must mean "show me the campus
                // overview", not "replay my last deep link". Explicit map deep
                // links (goNamed with a building param) are unaffected — they
                // navigate the branch directly, not through this tab handler.
                navigationShell.goBranch(
                  index,
                  initialLocation:
                      index == navigationShell.currentIndex ||
                      index == ShellBranchIndex.map,
                );
              },
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined, color: navLabelColor),
                  // Springy bounce-in on select.
                  selectedIcon: _TabIconFx(
                    icon: Icons.home,
                    color: navLabelColor,
                  ),
                  label: l10n.home,
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined, color: navLabelColor),
                  // "Opens" with a quarter turn.
                  selectedIcon: _TabIconFx(
                    icon: Icons.map,
                    color: navLabelColor,
                    turns: 0.25,
                  ),
                  label: l10n.navigation,
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.qr_code_scanner_outlined,
                    color: navLabelColor,
                  ),
                  selectedIcon: _TabIconFx(
                    icon: Icons.qr_code_scanner,
                    color: navLabelColor,
                  ),
                  label: l10n.scanTab,
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined, color: navLabelColor),
                  // The gear spins a full turn.
                  selectedIcon: _TabIconFx(
                    icon: Icons.settings,
                    color: navLabelColor,
                    turns: 1.0,
                  ),
                  label: l10n.settings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tab icon that plays a one-shot spring animation whenever it is mounted —
/// which, as a `NavigationDestination.selectedIcon`, is exactly the moment its
/// tab becomes selected. Bounces in; optionally spins [turns] full rotations
/// (e.g. the settings gear).
class _TabIconFx extends StatefulWidget {
  const _TabIconFx({required this.icon, required this.color, this.turns = 0.0});

  final IconData icon;
  final Color color;
  final double turns;

  @override
  State<_TabIconFx> createState() => _TabIconFxState();
}

class _TabIconFxState extends State<_TabIconFx>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: Icon(widget.icon, color: widget.color),
      builder: (context, child) {
        final t = _c.value;
        final scale = 0.7 + 0.3 * Curves.easeOutBack.transform(t);
        final angle =
            widget.turns * 2 * math.pi * Curves.easeOutCubic.transform(t);
        return Transform.rotate(
          angle: angle,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}
