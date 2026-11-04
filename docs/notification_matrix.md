# Notification Flow Matrix

> **Architecture inventory, reviewed 4 November 2026.** The current no-login app does not request or upload an FCM registration token (`fcm_service.dart`). The `notify` Edge Function and `user_fcm_tokens` table remain in the repository, but that is not proof of active remote-push delivery to this app. Local reminders are the supported flow to describe externally; the Android demo build lacked Firebase resource configuration, so remote-push behaviour was not verified.

All notification paths in Campus Navigation — push and local.

## Notification Types

| Type | Trigger | Delivery | Backend |
|------|---------|----------|---------|
| **Push: Announcement** | Server-side capability; no current client token registration | Not verified end to end | `notify` Edge Function + `user_fcm_tokens` |
| **Local: Study prompt** | Daily at user-configured time | flutter_local_notifications | Preference in local storage |

## Architecture

```
┌──────────────────────┐
│   Supabase Backend   │
│  ┌────────────────┐  │     FCM
│  │ Edge Function   │──────────────► Device (push)
│  │ notify          │  │
│  └────────────────┘  │
│  ┌────────────────┐  │
│  │ user_fcm_tokens │  │
│  └────────────────┘  │
└──────────────────────┘

┌──────────────────────┐
│   Flutter App        │
│  ┌────────────────┐  │
│  │ Local Notif     │  │     Scheduled locally
│  │ Service         │──────────────► OS notification tray
│  └────────────────┘  │
└──────────────────────┘
```

## FCM Token Lifecycle

The current app can request notification permission and display local reminders. FCM token registration was removed with the account flow; no token is requested or sent to `user_fcm_tokens` in the current client. Revisit this section if remote push delivery is intentionally reintroduced.

## Notification Channels (Android)

| Channel ID | Name | Importance | Sound |
|------------|------|-----------|-------|
| `study_prompts` | Study Prompts | Default | Default |
| `announcements` | Announcements | Default | Default |

## Notification Preferences

Preferences are stored locally via `flutter_secure_storage`:

| Preference | Default |
|------------|---------|
| Notifications enabled | true |
| Email notifications | false |
| Study prompt hour | 09 |
| Study prompt minute | 00 |

## Tap Routing

When user taps a notification:

| Notification Type | Route |
|-------------------|-------|
| Announcement | `/notifications` |
| Study prompt | `/home` |
