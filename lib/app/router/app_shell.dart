import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_navigation/app/l10n/generated/app_localizations.dart';
import 'package:campus_navigation/app/router/active_shell_branch_index_provider.dart';
import 'package:campus_navigation/app/router/route_names.dart';
import 'package:campus_navigation/app/router/shell_chrome_provider.dart';
import 'package:campus_navigation/app/theme/mq_spacing.dart';
import 'package:campus_navigation/features/settings/presentation/controllers/settings_controller.dart';
import 'package:campus_navigation/shared/widgets/glass_pane.dart';

/// Persistent bottom navigation shell wrapping the main tab destinations.
///
/// The bar retracts while a focused surface is open (Open Day picker, map
/// category sheet, …) so those workflows own the full screen and the map
/// gets the extra vertical space back — see [bottomNavVisibleProvider].
///
/// The Scan tab (Open Day QR codes, stamps and location cards) is part of the
/// optional Open Day experience, so it is only listed while Open Day is
/// switched on. Its shell branch always exists; only the destination is
/// hidden, which keeps [ShellBranchIndex] stable.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navVisible = ref.watch(bottomNavVisibleProvider);
    final openDayEnabled = ref.watch(
      settingsControllerProvider.select(
        (async) => async.value?.openDayEnabled ?? false,
      ),
    );

    // Publish the active branch so branch roots that stay mounted offstage
    // (ScanPage pauses its camera when not visible) can react to tab
    // switches. Deferred because providers can't be written during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(activeShellBranchIndexProvider.notifier)
          .setIndex(navigationShell.currentIndex);
    });

    final branches = <int>[
      ShellBranchIndex.home,
      ShellBranchIndex.map,
      if (openDayEnabled) ShellBranchIndex.scan,
      ShellBranchIndex.settings,
    ];
    final destinations = <int, NavigationDestination>{
      ShellBranchIndex.home: NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: l10n.home,
      ),
      ShellBranchIndex.map: NavigationDestination(
        icon: const Icon(Icons.map_outlined),
        selectedIcon: const Icon(Icons.map),
        label: l10n.navigation,
      ),
      ShellBranchIndex.scan: NavigationDestination(
        icon: const Icon(Icons.qr_code_scanner_outlined),
        selectedIcon: const Icon(Icons.qr_code_scanner),
        label: l10n.scanTab,
      ),
      ShellBranchIndex.settings: NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: l10n.settings,
      ),
    };
    // If Open Day is switched off while on the Scan tab, highlight Home
    // rather than throwing on a missing destination.
    final selected = branches.indexOf(navigationShell.currentIndex);

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: AnimatedSlide(
        // Slides out of frame rather than snapping, so a sheet opening over
        // the map doesn't read as a layout jump.
        offset: navVisible ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: navVisible ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          // Once hidden the bar must not swallow taps meant for the sheet
          // or the map underneath it.
          child: IgnorePointer(
            ignoring: !navVisible,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                MqSpacing.space3,
                0,
                MqSpacing.space3,
                MqSpacing.space3,
              ),
              child: GlassPane(
                isDark: isDark,
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: selected < 0 ? 0 : selected,
                  onDestinationSelected: (position) {
                    final index = branches[position];
                    navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    );
                  },
                  destinations: [for (final b in branches) destinations[b]!],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
