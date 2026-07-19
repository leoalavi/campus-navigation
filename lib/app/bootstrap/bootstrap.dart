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
      EnvConfig.validate();

      runApp(ProviderScope(child: ErrorBoundary(child: appBuilder())));
    },
    (error, stack) {
      AppLogger.error('Unhandled zone error', error, stack);
    },
  );
}
