import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/app/router/shell_chrome_provider.dart';
import 'package:mq_navigation/app/theme/mq_spacing.dart';
import 'package:mq_navigation/shared/widgets/glass_pane.dart';

/// Persistent bottom navigation shell wrapping the main tab destinations.
///
/// The bar retracts while a focused surface is open (Open Day picker, map
/// category sheet, …) so those workflows own the full screen and the map
/// gets the extra vertical space back — see [bottomNavVisibleProvider].
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navVisible = ref.watch(bottomNavVisibleProvider);

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
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) {
                    navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    );
                  },
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home),
                      label: l10n.home,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.map_outlined),
                      selectedIcon: const Icon(Icons.map),
                      label: l10n.navigation,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: l10n.settings,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
