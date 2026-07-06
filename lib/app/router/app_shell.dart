import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';

/// Persistent bottom navigation shell wrapping the main tab destinations.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Branch index of the Campus Map tab (see the StatefulShellRoute branch
  /// order in app_router.dart).
  static const int _mapBranchIndex = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navLabelColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          return TextStyle(color: navLabelColor);
        }),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // Navigate to the chosen branch. If the user taps the active tab,
          // the branch's navigation stack pops back to its root.
          //
          // The Campus Map tab ALWAYS resets to its root: the branch stack
          // preserves whatever deep-linked URL it last had (e.g.
          // `/map?building=X` from a "View on Campus Map" or AR flow), so
          // without the reset, returning to Navigation after visiting a
          // location re-restored that URL and force-reselected the stale
          // building. Tapping "Navigation" must mean "show me the campus
          // overview", not "replay my last deep link". Explicit map deep
          // links (goNamed with a building param) are unaffected — they
          // navigate the branch directly, not through this tab handler.
          navigationShell.goBranch(
            index,
            initialLocation:
                index == navigationShell.currentIndex ||
                index == _mapBranchIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: navLabelColor),
            selectedIcon: Icon(Icons.home, color: navLabelColor),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined, color: navLabelColor),
            selectedIcon: Icon(Icons.map, color: navLabelColor),
            label: l10n.navigation,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: navLabelColor),
            selectedIcon: Icon(Icons.settings, color: navLabelColor),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
