import 'dart:async';
import 'dart:ui' as ui;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/bootstrap/app_initialization.dart';
import 'package:mq_journey/app/app_link_coordinator.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/app_router.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_theme.dart';
import 'package:mq_journey/core/error/error_boundary.dart';
import 'package:mq_journey/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:mq_journey/features/open_day/data/open_day_reminder_scheduler.dart';
import 'package:mq_journey/features/scan/application/pending_stamp_award_controller.dart';
import 'package:mq_journey/features/scan/application/qr_scan_orchestrator.dart';
import 'package:mq_journey/features/scan/data/adapters/settings_progress_api_adapter.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/widgets/open_day_wordmark.dart';

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
  late final QrScanOrchestrator _openDayQrOrchestrator;
  late final AppLinkCoordinator _appLinkCoordinator;

  @override
  void initState() {
    super.initState();
    final verifier = ref.read(qrSignatureVerifierProvider);
    _openDayQrOrchestrator = QrScanOrchestrator(
      validate: (raw, isAllowlisted) =>
          verifier.validate(raw, isAllowlisted: isAllowlisted),
      loadTrail: () => ref.read(trailManifestProvider.future),
      progressApi: ref.read(progressApiProvider),
      clock: DateTime.now,
      navigate: (route) => ref.read(appRouterProvider).go(route),
      onRecorded: (visit) => ref
          .read(pendingStampAwardProvider.notifier)
          .setNotice(
            PendingStampNotice(
              locationId: visit.locationId,
              isNewVisit: visit.isNewVisit,
            ),
          ),
    );
    _appLinkCoordinator = AppLinkCoordinator(
      handleOpenDayQr: _handleOpenDayQr,
      navigate: (route) => ref.read(appRouterProvider).go(route),
    );
    _listenForDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _listenForDeepLinks() {
    // app_links 7 delivers both the initial cold-start URI and warm links on
    // this one stream. Using getInitialLink as well would create two ingresses.
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (!mounted) {
        return;
      }
      unawaited(_appLinkCoordinator.handle(uri));
    });
  }

  Future<void> _handleOpenDayQr(String raw) async {
    final outcome = await _openDayQrOrchestrator.handleCandidate(raw);
    if (outcome case QrScanSaveFailed(:final locationId)) {
      ref
          .read(pendingStampAwardProvider.notifier)
          .setNotice(
            PendingStampNotice(
              locationId: locationId,
              isNewVisit: false,
              saveFailed: true,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initAsync = ref.watch(appInitializationProvider);

    return initAsync.when(
      data: (_) {
        // ── Startup gate ─────────────────────────────────────────────
        // Never mount the router until persisted preferences (including
        // hasCompletedOnboarding) have RESOLVED. Without this, the router
        // defaulted to /home while settings were still loading, Home
        // painted for a frame or two, and only then did the redirect kick
        // the user to onboarding — the "Home flashes before onboarding"
        // bug. States: initialising → (onboarding | home), decided once.
        // If preference loading itself errors we proceed with defaults
        // rather than stranding the user on the splash forever.
        final preferencesAsync = ref.watch(settingsControllerProvider);
        if (!preferencesAsync.hasValue && !preferencesAsync.hasError) {
          return const _SplashView(isLoading: true);
        }

        // Watch global navigation state.
        final router = ref.watch(appRouterProvider);

        // Watch global preferences (theme, locale) loaded from local storage.
        final preferences = preferencesAsync.value;

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

/// Open Day 2026-branded splash. Shows while Firebase and Supabase
/// initialisation completes asynchronously.
class _SplashView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;

  const _SplashView({required this.isLoading, this.errorMessage});

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

  static const _backgroundAsset = 'assets/images/login_background.png';

  Widget _buildSplashScaffold() {
    return Scaffold(
      // Solid brand magenta base so any un-painted frame during startup is
      // still on-brand — never a black/blank flash.
      backgroundColor: MqColors.openDayMagenta,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Open Day 2026 arch photo, blurred beneath the brand scrim. If
          // the asset ever fails to load, the scrim gradient below still
          // paints a fully on-brand splash on its own.
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Image.asset(
              _backgroundAsset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              // Flyer-inspired: bright magenta falling into the deep plum
              // used on the campaign material's footer panel — translucent
              // so the arch photo reads through it.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MqColors.openDayMagenta.withValues(alpha: 0.78),
                  MqColors.openDayPlum.withValues(alpha: 0.88),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'MACQUARIE UNIVERSITY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        letterSpacing: 3.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const OpenDayWordmark(fontSize: 40),
                    const SizedBox(height: 18),
                    const OpenDayDateChip(),
                    const SizedBox(height: 56),
                    if (isLoading) ...[
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 40,
                        color: Colors.white,
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
