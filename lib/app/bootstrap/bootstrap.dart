import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:mq_journey/core/config/env_config.dart';
import 'package:mq_journey/core/error/error_boundary.dart';
import 'package:mq_journey/core/logging/app_logger.dart';
import 'package:mq_journey/shared/widgets/glass_shader.dart';

/// Initialises critical synchronous settings before the widget tree mounts.
///
/// Boot order:
/// 1. WidgetsFlutterBinding - required for system channels.
/// 2. Timezones - synchronous local DB setup.
/// 3. Error handlers - intercepts exceptions.
/// 4. EnvConfig.validate - validates variables before drawing frames.
/// 5. runApp - mounts the widget tree immediately.
///
/// Async initialisations (Firebase and Supabase) are handled
/// within a Riverpod provider after [runApp], allowing the branded Flutter
/// splash to paint before those services finish.
Future<void> bootstrap(Widget Function() appBuilder) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await GlassShaderCache.ensureLoaded();
      tz.initializeTimeZones();
      installErrorHandlers();

      // A pre-runApp failure (e.g. a release build missing its
      // --dart-define config) previously threw here and NOTHING was ever
      // mounted — the user sat on the native/HTML boot screen forever with
      // no feedback. Always mount *something*: on config failure, a clear
      // error screen instead of a silent hang.
      try {
        EnvConfig.validate();
      } on Object catch (error, stack) {
        AppLogger.error('Startup configuration invalid', error, stack);
        runApp(_BootFailureApp(message: error.toString()));
        return;
      }

      runApp(ProviderScope(child: ErrorBoundary(child: appBuilder())));
    },
    (error, stack) {
      AppLogger.error('Unhandled zone error', error, stack);
    },
  );
}

/// Minimal, dependency-free screen shown when startup configuration is
/// invalid. Deliberately avoids the app theme/l10n stack (which may be part
/// of what failed) — a plain branded surface with the failure reason.
class _BootFailureApp extends StatelessWidget {
  const _BootFailureApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFC6006F),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.build_circle_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'MQ Journey could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
