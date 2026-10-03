import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:campus_navigation/features/notifications/domain/entities/app_notification.dart';

/// Payload tag marking local notifications this app scheduled, so cleanup
/// never cancels another plugin's notifications.
const String kManagedNotificationTag = 'campus_navigation';

/// Tags this app owns, including those written by earlier builds (the app was
/// previously packaged as `mq_navigation`, and Open Day reminders came from
/// MQ Journey), so reminders scheduled before an upgrade are still cleaned up.
const Set<String> kOwnedNotificationTags = {
  kManagedNotificationTag,
  'mq_navigation',
  'mq_journey',
};

@immutable
class ReminderRequest {
  const ReminderRequest({
    required this.notificationId,
    required this.stableId,
    required this.type,
    required this.title,
    required this.body,
    required this.scheduledFor,
    this.link,
    this.payload = const <String, dynamic>{},
    this.repeatsDaily = false,
  });

  final int notificationId;
  final String stableId;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime scheduledFor;
  final String? link;
  final Map<String, dynamic> payload;
  final bool repeatsDaily;

  String get encodedPayload => jsonEncode(<String, dynamic>{
    'managedBy': kManagedNotificationTag,
    'notificationId': notificationId,
    'stableId': stableId,
    'type': type.value,
    'link': link,
    ...payload,
  });
}
