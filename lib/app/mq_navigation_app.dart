import 'dart:async';
import 'dart:ui' as ui;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/app/bootstrap/app_initialization.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/app/router/app_router.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/app/theme/mq_theme.dart';
import 'package:mq_navigation/core/error/error_boundary.dart';
import 'package:mq_navigation/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:mq_navigation/features/open_day/data/open_day_reminder_scheduler.dart';
import 'package:mq_navigation/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_navigation/core/logging/app_logger.dart';
import 'package:mq_navigation/features/deep_link/building_id_resolver.dart';
import 'package:mq_navigation/features/deep_link/deep_link_contract.dart';

/// The root Flutter application widget.
///
/// Composes global app state including routing, theme, and localization.
/// Also observes the notifications controller so that push notification
/// setup side-effects execute immediately upon app startup.
class MqNavigationApp extends ConsumerStatefulWidget {
  const MqNavigationApp({super.key});

  @override
  ConsumerState<MqNavigationApp> createState() => _MqNavigationAppState();
}

class _MqNavigationAppState extends ConsumerState<MqNavigationApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _listenForDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _listenForDeepLinks() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null && mounted) {
      // Cold start: the link that launched the app. Awaited so a resolved
      // destination replaces the map root before the user sees it.
      await _handleDeepLink(initial);
    }
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (!mounted) {
        return;
      }
      // Warm start: fire-and-forget, the stream callback cannot be async.
      unawaited(_handleDeepLink(uri));
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Public `/open` contract (mqnav:// and https://mqnavigation.app) — the
    // entry point Syllabus Sync uses. See deep_link_contract.dart.
    if (MqNavDeepLink.isOpenLink(uri)) {
      await _handleOpenLink(uri);
      return;
    }
    // Pre-existing "meet here" link on the legacy scheme. Left intact so
    // links already in the wild keep working.
    if (uri.scheme == MqNavDeepLink.legacyScheme && uri.host == 'meet') {
      // Guard: both parameters must be present and parseable. Null values
      // previously produced '/meet?lat=null&lng=null', which navigated to
      // MapPage with null coords and silently ignored navigation.
      final lat = double.tryParse(uri.queryParameters['lat'] ?? '');
      final lng = double.tryParse(uri.queryParameters['lng'] ?? '');
      if (lat == null || lng == null) return;
      ref.read(appRouterProvider).go('/meet?lat=$lat&lng=$lng');
    }
    // Anything else (Supabase auth callbacks, unrelated URLs) is not ours.
  }

  /// Routes an `/open` payload, resolving partner building ids first.
  ///
  /// A destination that names nothing we know does NOT silently become the map
  /// root: the user tapped "Navigate" expecting a place, so the map is opened
  /// with the id as a search term instead, which either finds it by name or
  /// shows an honest empty result. That also keeps ids minted by a future
  /// Syllabus Sync release from dead-ending.
  Future<void> _handleOpenLink(Uri uri) async {
    final target = parseMqNavDeepLink(uri.queryParameters);
    final router = ref.read(appRouterProvider);
    if (target is DeepLinkBuilding) {
      final canonical = await ref
          .read(buildingIdResolverProvider)
          .resolve(target.buildingId);
      if (!mounted) return;
      if (canonical == null) {
        AppLogger.warning(
          'Deep link named an unknown building: ${target.buildingId}',
        );
        router.go('/map?q=${Uri.encodeQueryComponent(target.buildingId)}');
        return;
      }
      router.go('/map/building/${Uri.encodeComponent(canonical)}');
      return;
    }
    // Search / meet-at / fallback need no resolution — reuse the router's
    // own contract mapping so there is one place that decides this.
    router.go(
      Uri(path: '/open', queryParameters: uri.queryParameters).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initAsync = ref.watch(appInitializationProvider);

    return initAsync.when(
      data: (_) {
        // Watch global navigation state.
        final router = ref.watch(appRouterProvider);

        // Watch global preferences (theme, locale) loaded from local storage.
        final preferences = ref.watch(settingsControllerProvider).value;

        // Explicitly watch the notifications controller to keep it alive.
        // This triggers FCM permission requests and token sync side effects
        // independently of whether the user is on the notifications page.
        ref.watch(notificationsControllerProvider);

        // Keep the Open Day reminder scheduler alive for the app lifetime.
        // The scheduler installs Riverpod listeners on bachelor selection,
        // notification toggles, and lead time — so reminders rebuild
        // automatically whenever the user changes any of those.
        ref.watch(openDayReminderSchedulerProvider);

        return MaterialApp.router(
          // The builder is used to wrap the entire app with a custom error widget.
          // If a widget fails to build, this prevents the grey "red screen of death"
          // and shows a friendlier fallback UI instead.
          builder: (context, child) {
            ErrorWidget.builder = (details) {
              final error = buildFrameworkErrorFallback(details.exception);
              if (child is Scaffold || child is Navigator) {
                return Scaffold(body: Center(child: error));
              }
              return error;
            };
            return child ??
                buildFrameworkErrorFallback(
                  StateError('Application shell failed to build.'),
                );
          },
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
          debugShowCheckedModeBanner: false,
          theme: MqTheme.light,
          darkTheme: MqTheme.dark,
          themeMode: preferences?.themeMode ?? ThemeMode.system,
          locale: preferences?.locale,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
      loading: () => const _SplashView(isLoading: true),
      error: (err, stack) =>
          _SplashView(isLoading: false, errorMessage: err.toString()),
    );
  }
}

/// A premium, beautiful Flutter-native splash view.
/// Shows while Firebase and Supabase initialisation completes asynchronously.
class _SplashView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;

  const _SplashView({required this.isLoading, this.errorMessage});

  static const _backgroundAsset = 'assets/images/splash_background.png';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MqTheme.light,
      darkTheme: MqTheme.dark,
      home: Scaffold(
        backgroundColor: MqColors.charcoal900,
        body: Stack(
          children: [
            // Background image (blurred, premium)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Image.asset(
                  _backgroundAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Dark scrim for premium readability
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
            // Centered branding/loading content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 4,
                        width: 120,
                        color: MqColors.red,
                        margin: const EdgeInsets.only(bottom: 32),
                      ),
                      const Icon(Icons.explore, size: 72, color: MqColors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Campus Navigation',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (isLoading) ...[
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              MqColors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Starting campus navigation...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 40,
                          color: MqColors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage ?? 'Service initialisation failed.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
