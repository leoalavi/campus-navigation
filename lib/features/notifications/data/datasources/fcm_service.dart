import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mq_navigation/core/logging/app_logger.dart';
import 'package:mq_navigation/features/notifications/data/datasources/local_notifications_service.dart';
import 'package:mq_navigation/features/notifications/domain/entities/app_notification.dart';

enum NotificationPermissionStatus {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  provisional,
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase may already be initialised or native config may be missing.
  }
  AppLogger.info('Handled background notification', message.messageId);
}

/// Wraps Firebase Cloud Messaging for remote push notifications.
///
/// Handles background handlers, permission requests, token acquisition,
/// and token syncing to the Supabase backend.
///
/// [messaging] is nullable: when [Firebase.apps] is empty (i.e. the native
/// Firebase config file is absent from the bundle), the provider passes `null`
/// and every FCM method becomes a safe no-op.  This keeps the app fully
/// functional on Supabase while FCM is treated as an optional capability.
class FcmService {
  FcmService({
    required FirebaseMessaging? messaging,
    required LocalNotificationsService localNotificationsService,
  }) : _messaging = messaging,
       _localNotificationsService = localNotificationsService;

  /// Null when Firebase was not initialised (e.g. missing GoogleService-Info.plist).
  final FirebaseMessaging? _messaging;
  final LocalNotificationsService _localNotificationsService;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openAppSubscription;
  bool _isInitialised = false;

  /// True only when the platform is supported AND Firebase was successfully
  /// initialised.  When [_messaging] is null (Firebase config absent), every
  /// public method returns early so no Firebase API is ever called.
  bool get _isSupported =>
      !kIsWeb &&
      _messaging != null &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize({
    required Future<void> Function(String link) onOpenLink,
  }) async {
    if (_isInitialised || !_isSupported) {
      return;
    }

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) async {
      final notification = AppNotification.fromRemoteMessage(message);
      await _localNotificationsService.showForegroundNotification(notification);
    });

    _openAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) async {
      final link = message.data['link'] as String?;
      if (link != null && link.isNotEmpty) {
        await onOpenLink(link);
      }
    });

    final initialMessage = await _messaging!.getInitialMessage();
    final link = initialMessage?.data['link'] as String?;
    if (link != null && link.isNotEmpty) {
      await onOpenLink(link);
    }

    _isInitialised = true;
  }

  Future<NotificationPermissionStatus> getPermissionStatus() async {
    if (!_isSupported) {
      return NotificationPermissionStatus.denied;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final permission = await Permission.notification.status;
      if (permission.isGranted) {
        return NotificationPermissionStatus.granted;
      }
      if (permission.isPermanentlyDenied) {
        return NotificationPermissionStatus.permanentlyDenied;
      }
      if (permission.isDenied || permission.isRestricted) {
        return NotificationPermissionStatus.denied;
      }
    }

    final settings = await _messaging!.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => NotificationPermissionStatus.granted,
      AuthorizationStatus.provisional =>
        NotificationPermissionStatus.provisional,
      AuthorizationStatus.denied => NotificationPermissionStatus.denied,
      AuthorizationStatus.notDetermined => NotificationPermissionStatus.unknown,
      // Web reports a fourth state the mobile SDKs never produce. Treated as
      // denied because that is what it means for the user: notifications are
      // off and the app cannot re-prompt.
      AuthorizationStatus.deniedPermanently =>
        NotificationPermissionStatus.denied,
    };
  }

  Future<NotificationPermissionStatus> requestPermission() async {
    if (!_isSupported) {
      return NotificationPermissionStatus.denied;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final permission = await Permission.notification.request();
      if (permission.isGranted) {
        return NotificationPermissionStatus.granted;
      }
      if (permission.isPermanentlyDenied) {
        return NotificationPermissionStatus.permanentlyDenied;
      }
    }

    final settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: defaultTargetPlatform == TargetPlatform.iOS,
    );
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => NotificationPermissionStatus.granted,
      AuthorizationStatus.provisional =>
        NotificationPermissionStatus.provisional,
      AuthorizationStatus.denied => NotificationPermissionStatus.denied,
      AuthorizationStatus.notDetermined => NotificationPermissionStatus.unknown,
      // Web reports a fourth state the mobile SDKs never produce. Treated as
      // denied because that is what it means for the user: notifications are
      // off and the app cannot re-prompt.
      AuthorizationStatus.deniedPermanently =>
        NotificationPermissionStatus.denied,
    };
  }

  // Token registration was removed with accounts: Campus Navigation has no
  // server-side user to address a push at, so no FCM registration token is
  // ever requested or transmitted. Firebase Messaging is retained only for the
  // notification-permission flow and foreground message display that local
  // reminders share. See docs/PRIVACY.md.

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openAppSubscription?.cancel();
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  // Guard: FirebaseMessaging.instance throws if Firebase.initializeApp() was
  // never called (e.g. GoogleService-Info.plist / google-services.json absent).
  // Passing null lets FcmService treat every FCM operation as a safe no-op,
  // keeping the Supabase-first app fully functional without a Firebase config.
  final messaging = Firebase.apps.isNotEmpty
      ? FirebaseMessaging.instance
      : null;
  final service = FcmService(
    messaging: messaging,
    localNotificationsService: ref.watch(localNotificationsServiceProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});
