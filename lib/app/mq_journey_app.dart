import 'dart:async';
import 'dart:ui' as ui;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/bootstrap/app_initialization.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/app_router.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_theme.dart';
import 'package:mq_journey/core/error/error_boundary.dart';
import 'package:mq_journey/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:mq_journey/features/open_day/data/open_day_reminder_scheduler.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';

/// The root Flutter application widget.
///
/// Composes global app state including routing, theme, and localization.
/// Also observes the notifications controller so that push notification
/// setup side-effects execute immediately upon app startup.
class MqJourneyApp extends ConsumerStatefulWidget {
  const MqJourneyApp({super.key});

  @override
  ConsumerState<MqJourneyApp> createState() => _MqJourneyAppState();
}

class _MqJourneyAppState extends ConsumerState<MqJourneyApp> {
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
      _handleDeepLink(initial);
    }
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (!mounted) {
        return;
      }
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.host != 'meet' ||
        (uri.scheme != 'io.mqjourney' && uri.scheme != 'io.mqnavigation')) {
      return;
    }

    final latStr = uri.queryParameters['lat'];
    final lngStr = uri.queryParameters['lng'];

    // Guard: both parameters must be present and parseable.
    // Previously null values produced '/meet?lat=null&lng=null', which
    // navigated to MapPage with null coords and silently ignored navigation.
    final lat = latStr != null ? double.tryParse(latStr) : null;
    final lng = lngStr != null ? double.tryParse(lngStr) : null;
    if (lat == null || lng == null) {
      return;
    }

    final router = ref.read(appRouterProvider);
    router.go('/meet?lat=$lat&lng=$lng');
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

  static const _backgroundAsset = 'assets/images/login_background.png';

  @override
  Widget build(BuildContext context) {
    // Uses `onGenerateInitialRoutes` instead of `home` so this splash screen
    // always renders regardless of the platform's requested initial route
    // (e.g. a cold start via a deep link to "/map"). The real router
    // (`GoRouter`, mounted once app initialization completes) is the one
    // that honours that initial route. If we used `home` here instead,
    // Flutter's default initial-route matching would run against this
    // temporary MaterialApp — which has no matching routes — logging a
    // spurious "Could not navigate to initial route" framework error even
    // though navigation ultimately succeeds once the real router mounts.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MqTheme.light,
      darkTheme: MqTheme.dark,
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(builder: (context) => _buildSplashScaffold()),
      ],
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (context) => _buildSplashScaffold()),
      builder: (context, child) => child ?? _buildSplashScaffold(),
    );
  }

  Widget _buildSplashScaffold() {
    return Scaffold(
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
                      'MQ Navigation',
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
    );
  }
}
