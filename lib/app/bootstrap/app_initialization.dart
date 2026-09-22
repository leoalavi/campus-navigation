import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mq_navigation/core/config/env_config.dart';
import 'package:mq_navigation/core/logging/app_logger.dart';
import 'package:mq_navigation/features/map/data/services/offline_maps_service.dart';
import 'package:mq_navigation/features/notifications/data/datasources/fcm_service.dart';

/// Provider that performs asynchronous startup tasks in the background.
///
/// This includes:
/// 1. Firebase core initialisation (required for FCM notifications).
/// 2. Supabase client setup (required for all backend operations).
/// 3. Offline map caching backend setup (ObjectBox FFI).
///
/// Running these tasks in a provider allows the main MaterialApp to build
/// instantly and show a premium Flutter-native splash/loading screen,
/// preventing the Xcode/LLDB watchdog from timing out during debug runs.
final appInitializationProvider = FutureProvider<void>((ref) async {
  AppLogger.info('Asynchronous service initialisation started');

  // Run Firebase and Supabase initialisation in parallel.
  await Future.wait([
    // Initialize Firebase (FCM notifications, optional fallback)
    Future(() async {
      if (kIsWeb) return;
      try {
        await Firebase.initializeApp().timeout(const Duration(seconds: 5));
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
        AppLogger.info('Firebase asynchronously initialised');
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Firebase initialisation skipped in background. FCM push notifications unavailable.',
          error,
          stackTrace,
        );
      }
    }),

    // Initialize Supabase (Primary backend API client)
    Future(() async {
      try {
        await Supabase.initialize(
          url: EnvConfig.supabaseUrl,
          publishableKey: EnvConfig.supabaseAnonKey,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        ).timeout(const Duration(seconds: 10));
        AppLogger.info('Supabase asynchronously initialised');
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Supabase initialisation stalled in background — proceeding without cached session. '
          'User will be redirected to login if not authenticated.',
          error,
          stackTrace,
        );
      }
    }),
  ]);

  // After primary services are loaded, initialize Offline Maps.
  // This executes after runApp() has drawn frames, preventing the ObjectBox
  // native dynamic library load (FFI) from delaying the initial frame rendering.
  try {
    await const OfflineMapsService().initializeBackend();
    AppLogger.info('Offline-maps backend asynchronously initialised');
  } catch (error, stackTrace) {
    AppLogger.warning(
      'Offline-maps backend initialisation skipped in background. '
      'Online-only map tiles will be used.',
      error,
      stackTrace,
    );
  }
});
