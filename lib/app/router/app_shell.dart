import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/active_shell_branch_index_provider.dart';
import 'package:mq_journey/app/router/liquid_tab_bar.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
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
            animated: true, // the hero island gets the living highlights
            child: LiquidTabBar(
              color: navLabelColor,
              accent: MqColors.red, // scanline laser + viewfinder lock

              currentIndex: navigationShell.currentIndex,
              onSelected: (index) {
                // Navigate to the chosen branch. If the user taps the active
                // tab, the branch's navigation stack pops back to its root.
                //
                // The Journey (Campus Map) tab ALWAYS resets to its root so
                // that tapping "Journey" means "show me the campus overview",
                // not "replay my last deep link". Explicit map deep links
                // (goNamed with a building param) are unaffected.
                navigationShell.goBranch(
                  index,
                  initialLocation:
                      index == navigationShell.currentIndex ||
                      index == ShellBranchIndex.map,
                );
              },
              items: [
                LiquidNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: l10n.home,
                  fx: TabFx.bounce,
                ),
                LiquidNavItem(
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map,
                  label: l10n.navigation,
                  fx: TabFx.rotateOpen,
                ),
                LiquidNavItem(
                  icon: Icons.qr_code_scanner_outlined,
                  activeIcon: Icons.qr_code_scanner,
                  label: l10n.scanTab,
                  fx: TabFx.scanline,
                ),
                LiquidNavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: l10n.settings,
                  fx: TabFx.spin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
