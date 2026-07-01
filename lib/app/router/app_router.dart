import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/router/app_shell.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/core/config/env_config.dart';
import 'package:mq_journey/features/deep_link/deep_link_contract.dart';
import 'package:mq_journey/features/home/presentation/pages/home_page.dart';
import 'package:mq_journey/features/home/presentation/pages/onboarding_page.dart';
import 'package:mq_journey/features/map/presentation/pages/map_page.dart';
import 'package:mq_journey/features/map/presentation/pages/favorites_page.dart';
import 'package:mq_journey/features/notifications/presentation/pages/notifications_page.dart';
import 'package:mq_journey/features/open_day/presentation/pages/open_day_page.dart';
import 'package:mq_journey/features/open_day/presentation/pages/your_day_page.dart';
import 'package:mq_journey/features/safety/presentation/pages/safety_toolkit_page.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/features/settings/presentation/pages/settings_page.dart';
import 'package:mq_journey/features/scan/presentation/pages/scan_page.dart';
import 'package:mq_journey/features/scan/presentation/pages/location_card_page.dart';
import 'package:mq_journey/features/scan/presentation/pages/location_ar_page.dart';
import 'package:mq_journey/features/scan/presentation/pages/indoor_preview_page.dart';
import 'package:mq_journey/features/scan/presentation/pages/stamps_passport_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Central GoRouter configuration for the app.
/// Uses a stateful shell so each bottom-tab branch keeps its own
/// navigation stack instead of resetting when the user switches tabs.
///
/// **Why we use `.select()` instead of `ref.watch(settingsControllerProvider)`:**
/// The redirect callback only depends on two pieces of settings state —
/// the loading flag and `hasCompletedOnboarding`. If we watched the entire
/// settings AsyncValue, *every* preference change (theme, locale, bachelor,
/// commute mode, …) would invalidate this provider. That recreates the
/// whole `GoRouter`, which in turn makes Flutter rebuild the active
/// MaterialPage and replay its entry transition — i.e. a full-screen
/// slide on every preference toggle. Scoping the dependency with
/// `.select()` keeps preference changes silent at the router level so
/// only true navigation triggers transitions.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    debugLogDiagnostics: EnvConfig.isDevelopment,
    redirect: (context, state) {
      final path = state.matchedLocation;
      if (path == '/onboarding') return null;

      final settingsAsync = ref.read(settingsControllerProvider);
      if (settingsAsync.isLoading) return null;
      final hasCompleted = settingsAsync.value?.hasCompletedOnboarding ?? false;

      if (!hasCompleted) {
        return '/onboarding';
      }
      return null;
    },
    refreshListenable: _OnboardingFlagListenable(ref),
    routes: [
      // Syllabus Sync integration entry point.
      //
      // Stable, versioned public URL — see deep_link_contract.dart for the
      // supported payload shape. Internal routes may change; this one may
      // NOT change without a compatibility plan for Syllabus Sync clients.
      GoRoute(
        path: '/open',
        redirect: (context, state) {
          final target = parseMqNavDeepLink(state.uri.queryParameters);
          return switch (target) {
            DeepLinkBuilding(:final buildingId) =>
              '/map/building/${Uri.encodeComponent(buildingId)}',
            DeepLinkSearch(:final query) =>
              '/map?q=${Uri.encodeQueryComponent(query)}',
            DeepLinkMeetAt(:final latitude, :final longitude) =>
              '/map?lat=$latitude&lng=$longitude',
            DeepLinkFallback() => '/map',
          };
        },
      ),
      // Notifications sits outside the shell so it covers the bottom nav bar.
      GoRoute(
        path: '/meet',
        name: RouteNames.meet,
        redirect: (context, state) {
          final lat = state.uri.queryParameters['lat'];
          final lng = state.uri.queryParameters['lng'];
          if (lat != null && lng != null) {
            return '/map?lat=$lat&lng=$lng';
          }
          return '/map';
        },
      ),
      GoRoute(
        path: '/notifications',
        name: RouteNames.notifications,
        builder: (context, state) => const NotificationsPage(),
      ),
      // Open Day — dedicated screen, deliberately *outside* the bottom-nav
      // shell so it doesn't permanently consume one of the three tabs.
      // Open Day is a temporal feature; pushing it here keeps the nav
      // surface stable post-Open-Day.
      GoRoute(
        path: '/open-day',
        name: RouteNames.openDay,
        builder: (context, state) => const OpenDayPage(),
      ),
      GoRoute(
        path: '/your-day',
        name: RouteNames.yourDay,
        builder: (context, state) => const YourDayPage(),
      ),
      GoRoute(
        path: '/onboarding',
        name: RouteNames.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      // Safety Toolkit — standalone page for campus safety features.
      // Accessible from the settings page or map overflow menu.
      // Privacy-safe: NO automatic location sharing — user manually calls or navigates.
      GoRoute(
        path: '/safety',
        name: RouteNames.safetyToolkit,
        builder: (context, state) => const SafetyToolkitPage(),
      ),
      // Favorites page
      GoRoute(
        path: '/favorites',
        name: RouteNames.favorites,
        builder: (context, state) => const FavoritesPage(),
      ),
      // Stamps passport — Open Day collectible progress screen.
      GoRoute(
        path: '/stamps',
        name: RouteNames.stamps,
        builder: (context, state) => const StampsPassportPage(),
      ),
      // QR scanner — camera surface for scanning Open Day QR codes.
      GoRoute(
        path: '/scan',
        name: RouteNames.scan,
        builder: (context, state) => const ScanPage(),
      ),
      // Scanned-location card — full-page detail for a QR-resolved location.
      GoRoute(
        path: '/location/:locationId',
        name: RouteNames.locationDetail,
        builder: (context, state) => LocationCardPage(
          locationId: state.pathParameters['locationId'] ?? '',
        ),
        routes: [
          GoRoute(
            path: 'ar',
            name: RouteNames.locationAr,
            builder: (context, state) => LocationArPage(
              locationId: state.pathParameters['locationId'] ?? '',
              stopId: state.uri.queryParameters['stop'],
            ),
          ),
        ],
      ),
      // The shell route handles the bottom navigation bar and nested routing.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: RouteNames.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                name: RouteNames.map,
                builder: (context, state) => MapPage(
                  initialBuildingId: state.uri.queryParameters['building'],
                  initialSearchQuery: state.uri.queryParameters['q'],
                  meetLat: double.tryParse(
                    state.uri.queryParameters['lat'] ?? '',
                  ),
                  meetLng: double.tryParse(
                    state.uri.queryParameters['lng'] ?? '',
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'building/:buildingId',
                    name: RouteNames.buildingDetail,
                    builder: (context, state) => MapPage(
                      initialBuildingId: state.pathParameters['buildingId'],
                    ),
                  ),
                  GoRoute(
                    path: 'building/:buildingId/indoor',
                    name: RouteNames.indoorPreview,
                    builder: (context, state) => IndoorPreviewPage(
                      buildingId: state.pathParameters['buildingId'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: RouteNames.settings,
                builder: (context, state) => SettingsPage(
                  initialSection: state.uri.queryParameters['section'],
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// [Listenable] adapter for `GoRouter.refreshListenable`.
///
/// Fires whenever the onboarding-completion flag in settings changes,
/// so the router redirects away from /onboarding once the user finishes it.
class _OnboardingFlagListenable extends ChangeNotifier {
  _OnboardingFlagListenable(Ref ref) {
    _settingsSub = ref.listen<({bool isLoading, bool hasCompleted})>(
      settingsControllerProvider.select(
        (s) => (
          isLoading: s.isLoading,
          hasCompleted: s.value?.hasCompletedOnboarding ?? false,
        ),
      ),
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
    ref.onDispose(() {
      _settingsSub?.close();
    });
  }

  ProviderSubscription<({bool isLoading, bool hasCompleted})>? _settingsSub;
}
