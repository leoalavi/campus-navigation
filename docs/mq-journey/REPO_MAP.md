# MQ Journey - Repository Map

Last audited: 2026-07-09 (Australia/Sydney)

This file is the fast orientation map for the MQ Journey Flutter repository. It is written for engineers who need to understand where things live, how the app boots, how data moves, and which files are high-risk when changing behavior.

## 1. Executive Summary

MQ Journey is a Flutter campus companion for Macquarie University. The app combines an illustrated campus map, routing, QR scanning, Open Day schedules, indoor 360-degree previews, collectible stamps, favorites, notifications, safety tools, timetable parsing, transit departures, and 35-locale localization.

Core architectural facts:

- Package name: `mq_journey`
- Runtime: Flutter / Dart SDK `^3.11.0`
- App shell: `go_router` `StatefulShellRoute.indexedStack`
- State: Riverpod 3 (`flutter_riverpod ^3.3.2`)
- Backend: Supabase with silent anonymous auth, Postgres, RLS, Realtime, and Edge Functions
- Firebase role: messaging/bootstrap only, not analytics
- Auth stance: no login UI; silent anonymous sessions only
- Privacy stance: no tracking SDKs, no Google Maps SDK, no persistent location history
- Feature shape: feature-first folders with `domain`, `data`, and `presentation` layers where the feature is large enough

The app starts at `/home`, redirects to `/onboarding` until local preferences mark onboarding complete, and uses four persistent bottom-nav branches: Home, Journey/Map, Scan, and Settings.

## 2. Current Repository Scale

These counts exclude generated build output but include checked-in source and assets:

| Area | Count | Meaning |
|---|---:|---|
| `lib/app` | 83 files | App composition, router, generated l10n, theme |
| `lib/core` | 9 files | Config, error, logging, networking, security, utilities |
| `lib/shared` | 10 files | Reusable widgets, context extensions, preferences model |
| `lib/features` | 131 Dart files | Product features |
| `test` | 88 test files | Unit/widget coverage by app area |
| `supabase/migrations` | 67 SQL files | Shared backend schema history |
| `supabase/functions` | 5 TypeScript files | Edge Functions plus shared CORS |
| `assets/data` | 41 files | App data, including indoor manifests and Open Day JSON |
| `assets/maps` | 5 files | Campus raster plus overlays |
| `assets/images` | 5 files | Branding and splash/home imagery |
| `assets/web` | 3 files | Indoor WebView and Pannellum runtime |

Feature Dart file counts:

| Feature | Files | Main concern |
|---|---:|---|
| `scan` | 42 | QR scanner, location cards, indoor preview, stamps |
| `map` | 37 | Campus map, routing, building registry, AR picker |
| `open_day` | 13 | Open Day data, suggestions, reminders, itinerary |
| `notifications` | 11 | FCM/local notifications and Supabase notification rows |
| `favorites` | 5 | Favorite buildings CRUD |
| `safety` | 5 | Emergency contacts, AED/first-aid points, torch |
| `auth` | 3 | Anonymous Supabase auth facade |
| `settings` | 3 | Preferences persistence and settings UI |
| `timetable` | 3 | iCal timetable storage/parsing |
| `transit` | 3 | TfNSW stop/departure providers |
| `home` | 2 | Home dashboard and onboarding |
| `deep_link` | 1 | Stable `/open` integration contract |

## 3. Top-Level Layout

```text
MQ_Journey/
├── AGENT.md                         # Append-only agent history and continuity notes
├── CHANGELOG.md                     # Human-readable change log
├── CLAUDE.md                        # Claude/agent-oriented project notes
├── CODE_OF_CONDUCT.md               # Community conduct policy
├── CONTRIBUTING.md                  # Contributor guidance
├── LICENSE                          # Project license
├── PROJECT_REPORT.md                # Course/report artifact referenced by README
├── README.md                        # Product/marker-facing overview
├── REPO_MAP.md                      # This file
├── analysis_options.yaml            # Analyzer/lint config
├── l10n.yaml                        # Flutter localization generation config
├── pubspec.yaml                     # Package metadata, deps, assets, launcher icons
├── android/                         # Android platform host project
├── ios/                             # iOS platform host project
├── macos/                           # macOS platform host project
├── linux/                           # Linux platform host project
├── windows/                         # Windows platform host project
├── web/                             # Web host files, manifest, icons
├── assets/                          # Bundled JSON, images, maps, web viewer assets
├── docs/                            # Architecture/security/inventory docs
├── lib/                             # Flutter/Dart application source
├── scripts/                         # Local quality/deploy helper scripts
├── screenshots/                     # README/project report screenshots
├── supabase/                        # Supabase config, migrations, Edge Functions
├── test/                            # Flutter unit/widget tests
└── tools/                           # One-off repo maintenance/generation scripts
```

Generated and local-output directories such as `.dart_tool/`, `build/`, coverage output, and script logs are not part of the source map.

## 4. Runtime Stack

| Concern | Dependency | Version in `pubspec.yaml` | Notes |
|---|---|---:|---|
| Flutter | `flutter` | SDK | Main UI framework |
| Dart | SDK constraint | `^3.11.0` | Language floor |
| Supabase | `supabase_flutter` | `^2.15.1` | Anonymous auth, DB, Realtime, Edge Function calls |
| Firebase bootstrap | `firebase_core` | `^4.2.0` | Used by messaging setup |
| Push | `firebase_messaging` | `^16.1.2` | Optional FCM token sync |
| Local notifications | `flutter_local_notifications` | `^21.0.0` | Local reminders and notification UI |
| State | `flutter_riverpod` | `^3.3.2` | Providers, notifiers, async state |
| Router | `go_router` | `^17.3.0` | Shell route and standalone routes |
| i18n | `flutter_localizations`, `intl` | SDK / `^0.20.2` | 35 ARB locales |
| Maps | `flutter_map` | `^8.3.0` | Illustrated campus map with custom CRS |
| Offline tiles | `flutter_map_tile_caching` | `^10.1.1` | Optional tile cache provider |
| Coordinates | `latlong2` | `^0.9.1` | Lat/lng and bounds types |
| GPS | `geolocator` | `^14.0.2` | Current/last-known device location |
| Permissions | `permission_handler` | `^12.0.1` | Runtime permission flows |
| Secure local store | `flutter_secure_storage` | `^10.0.0` | Mobile secure storage, desktop/web fallback |
| Deep links | `app_links` | `^7.0.0` | Custom scheme and initial link handling |
| Connectivity | `connectivity_plus` | `^7.0.0` | Online/offline stream |
| HTTP | `http` | `^1.4.0` | TfNSW provider and simple clients |
| Compass | `flutter_compass` | `^0.8.1` | On-device heading |
| QR camera | `mobile_scanner` | `^7.2.0` | Scan tab camera surface |
| Indoor WebView | `flutter_inappwebview` | `^6.1.5` | Pannellum 360-degree viewer |
| Torch | `torch_light` | `^1.1.0` | Safety flashlight |
| Sharing | `share_plus` | `^12.0.2` | Meet/share flows |
| URLs | `url_launcher` | `^6.3.1` | Phone calls and external URLs |
| Timetable parsing | `icalendar_parser` | `^2.1.0` | iCal class parsing |
| Preferences fallback | `shared_preferences` | `^2.5.0` | Desktop/web local persistence |
| Timezones | `timezone` | `^0.11.0` | Notification scheduling |
| UI effect | `confetti` | `^0.8.0` | Stamp/reward presentation |
| Tests | `flutter_test`, `integration_test`, `mocktail` | SDK / `^1.0.4` | Test suite |
| Lints | `flutter_lints` | `^6.0.0` | Static lint base |

## 5. App Boot and Global Flow

Entry path:

```text
lib/main.dart
  -> bootstrap(() => const MqJourneyApp())
     -> ProviderScope
     -> ErrorBoundary
     -> MqJourneyApp
        -> appInitializationProvider
        -> MaterialApp.router
```

Key files:

- `lib/main.dart`: tiny entrypoint; delegates to bootstrap.
- `lib/app/bootstrap/bootstrap.dart`: wraps startup in `runZonedGuarded`, `ProviderScope`, and `ErrorBoundary`.
- `lib/app/bootstrap/app_initialization.dart`: initializes Firebase and Supabase, then ensures silent anonymous auth.
- `lib/app/mq_journey_app.dart`: root app widget; wires theme, locale, router, deep links, notifications, reminders, and splash state.
- `lib/app/router/app_router.dart`: central route tree and onboarding redirect.
- `lib/app/router/route_names.dart`: route-name constants and bottom-branch indices.

Global startup side effects:

- Firebase and Supabase are initialized before the router is mounted.
- Supabase anonymous sign-in is attempted silently.
- `notificationsControllerProvider` is watched at app level so FCM/local notification setup can run.
- `openDayReminderSchedulerProvider` is watched at app level so reminder listeners stay alive.
- `AppLinks` listens for `io.mqjourney://meet?lat=...&lng=...` and legacy `io.mqnavigation://meet?...` links.

## 6. Routing Map

The router starts at `/home`, but redirects to `/onboarding` until `settingsControllerProvider` reports `hasCompletedOnboarding == true`.

Standalone routes:

| Route name | Path | Widget / behavior | Notes |
|---|---|---|---|
| none | `/open` | redirect only | Stable Syllabus Sync contract parsed by `deep_link_contract.dart` |
| `meet` | `/meet` | redirect only | Sends valid `lat`/`lng` to `/map?lat=...&lng=...` |
| `notifications` | `/notifications` | `NotificationsPage` | Outside shell so it covers bottom nav |
| `open-day` | `/open-day` | `OpenDayPage` | Temporal Open Day feature |
| `your-day` | `/your-day` | `YourDayPage` | User itinerary |
| `onboarding` | `/onboarding` | `OnboardingPage` | First-run gate |
| `safety` | `/safety` | `SafetyToolkitPage` | Standalone safety page |
| `favorites` | `/favorites` | `FavoritesPage` | Favorite buildings list |
| `stamps` | `/stamps` | `StampsPassportPage` | Open Day stamp passport |
| `location-detail` | `/location/:locationId` | `LocationCardPage` | QR-resolved location detail |
| `location-ar` | `/location/:locationId/ar?stop=...` | `LocationArPage` | AR/indoor stop context for scanned location |

Shell routes:

| Branch index | Route name | Path | Widget | Role |
|---:|---|---|---|---|
| 0 | `home` | `/home` | `HomePage` | Dashboard and entry actions |
| 1 | `map` | `/map` | `MapPage` | Journey/campus map |
| 1 child | `building-detail` | `/map/building/:buildingId` | `MapPage` | Opens map focused on a building |
| 1 child | `indoor-preview` | `/map/building/:buildingId/indoor` | `IndoorPreviewPage` | Building indoor 360-degree viewer |
| 2 | `scan` | `/scan` | `ScanPage` | Persistent QR scanner tab |
| 3 | `settings` | `/settings?section=...` | `SettingsPage` | Preferences and privacy controls |

Important router details:

- `ShellBranchIndex` is the single source of truth for bottom-tab ordering.
- The Scan branch lives inside the shell and persists like the other tabs.
- `ScanPage` lifecycle code depends on `activeShellBranchIndexProvider` so the camera pauses when the Scan tab is not active.
- `/open` is an integration contract; changing it requires backward compatibility planning.

## 7. Source Tree: `lib/app`

```text
lib/app/
├── bootstrap/
│   ├── app_initialization.dart       # Firebase + Supabase + anonymous session startup
│   └── bootstrap.dart                # Zone, ProviderScope, ErrorBoundary wrapper
├── l10n/
│   ├── app_*.arb                     # 35 locale source files
│   └── generated/                    # Generated AppLocalizations files
├── router/
│   ├── active_shell_branch_index_provider.dart
│   ├── app_router.dart
│   ├── app_shell.dart
│   └── route_names.dart
├── theme/
│   ├── mq_animations.dart
│   ├── mq_colors.dart
│   ├── mq_spacing.dart
│   ├── mq_theme.dart
│   └── mq_typography.dart
└── mq_journey_app.dart
```

Responsibilities:

- `bootstrap`: startup safety, async service initialization, app-level error handling.
- `router`: named routes, onboarding redirect, bottom navigation shell.
- `theme`: MQ design tokens. Feature UI should use these instead of raw colors/sizes.
- `l10n`: ARB source and generated localizations. Edit ARB source, then run `flutter gen-l10n`.

## 8. Source Tree: `lib/core`

```text
lib/core/
├── config/
│   └── env_config.dart               # --dart-define config and debug fallback values
├── error/
│   ├── app_exception.dart            # App exception hierarchy
│   └── error_boundary.dart           # Widget/framework error fallback
├── logging/
│   └── app_logger.dart               # Logger facade
├── network/
│   ├── connectivity_service.dart     # Connectivity stream/provider
│   └── session_guard.dart            # Ensures Supabase auth session before writes
├── security/
│   └── secure_storage_service.dart   # Secure storage with SharedPreferences fallback
└── utils/
    ├── haptics.dart                  # Haptic helper
    └── result.dart                   # Result type
```

High-risk files:

- `env_config.dart`: config/secrets boundary. Public anon keys are allowed only as RLS-enforced public config; never add service-role keys.
- `session_guard.dart`: write-path auth reliability. Many Supabase write features depend on this seam.
- `secure_storage_service.dart`: local persistence and desktop/web fallback.

## 9. Source Tree: `lib/shared`

```text
lib/shared/
├── extensions/
│   └── context_extensions.dart
├── models/
│   └── user_preferences.dart         # Central local preferences model
└── widgets/
    ├── glass_pane.dart
    ├── mq_app_bar.dart
    ├── mq_bottom_sheet.dart
    ├── mq_button.dart
    ├── mq_card.dart
    ├── mq_input.dart
    ├── mq_tactile_button.dart
    └── open_day_wordmark.dart
```

Use shared widgets for recurring MQ-styled controls. `UserPreferences` is the model persisted by Settings and read throughout Open Day, map, notifications, locale/theme, onboarding, and scan-progress flows.

## 10. Feature Map

### `features/auth`

```text
auth/
├── data/repositories/auth_repository.dart
├── domain/services/auth_service.dart
└── presentation/controllers/auth_controller.dart
```

Purpose:

- Keeps auth as a narrow anonymous-session facade.
- Exposes `authRepositoryProvider` and `authControllerProvider`.
- Avoids login/signup/password UI and password auth calls.

Important behavior:

- `AuthService` wraps Supabase auth operations.
- `AuthRepository.userId` is used by favorites and notifications.
- Write paths should use `sessionGuardProvider` rather than manually recovering sessions.

### `features/deep_link`

```text
deep_link/
└── deep_link_contract.dart
```

Purpose:

- Parses stable `/open` query payloads from sister apps.
- Produces typed targets such as building, search, meet-at, or fallback.

Risk:

- This is an external integration boundary. Keep backward compatibility unless a migration plan exists.

### `features/home`

```text
home/
└── presentation/pages/
    ├── home_page.dart
    └── onboarding_page.dart
```

Purpose:

- Home dashboard with Open Day modules, metro departures, map entry, QR CTA, safety/settings paths.
- Onboarding completion updates settings preferences.

Key dependencies:

- `settingsControllerProvider`
- `tfnswMetroProvider`
- `mapControllerProvider`
- Open Day providers and widgets

### `features/map`

```text
map/
├── data/
│   ├── datasources/
│   │   ├── building_registry_source.dart
│   │   ├── campus_routes_remote_source.dart
│   │   ├── location_source.dart
│   │   ├── map_assets_source.dart
│   │   ├── maps_routes_remote_source.dart
│   │   └── overlay_registry.dart
│   ├── mappers/campus_projection_impl.dart
│   ├── repositories/map_repository_impl.dart
│   └── services/offline_maps_service.dart
├── domain/
│   ├── entities/
│   │   ├── building.dart
│   │   ├── campus_overlay_meta.dart
│   │   ├── campus_point.dart
│   │   ├── map_overlay.dart
│   │   ├── nav_instruction.dart
│   │   └── route_leg.dart
│   └── services/
│       ├── building_search.dart
│       ├── campus_projection.dart
│       ├── geo_utils.dart
│       └── map_polyline_codec.dart
└── presentation/
    ├── controllers/map_controller.dart
    ├── pages/
    │   ├── favorites_page.dart
    │   └── map_page.dart
    └── widgets/
        ├── ar_building_picker.dart
        ├── building_actions_sheet.dart
        ├── building_search_sheet.dart
        ├── campus/
        │   ├── campus_map_location_layer.dart
        │   ├── campus_map_marker_layer.dart
        │   ├── campus_map_overlay.dart
        │   ├── campus_map_route_layer.dart
        │   ├── campus_map_view.dart
        │   └── campus_overlay_layers.dart
        ├── compass_mode_view.dart
        ├── map_mode_toggle.dart
        ├── map_shell.dart
        ├── map_view_helpers.dart
        ├── overlay_picker_sheet.dart
        └── route_panel.dart
```

Purpose:

- Renders the illustrated campus map.
- Loads building registry from Supabase-backed `app_config`, with local cache.
- Supports search, selected building details, overlays, route preview/navigation, current location, compass mode, and AR/indoor entry points.

Key providers/classes:

- `mapControllerProvider`: `AsyncNotifierProvider<MapController, MapState>`
- `campusMapIntentProvider`: integer bump notifier used to focus the map from other features.
- `mapRepositoryProvider`: repository abstraction over building registry, routing, and location.
- `buildingRegistryProvider`: async building list.
- `locationSourceProvider`: GPS/permission access.
- `mapsRoutesRemoteSourceProvider`: Supabase Edge Function route client.
- `offlineMapsServiceProvider`: tile provider/cache wrapper.

Data flow:

```text
MapPage
  -> mapControllerProvider
     -> mapRepositoryProvider
        -> buildingRegistrySourceProvider
        -> campusRoutesRemoteSourceProvider
        -> locationSourceProvider
        -> mapAssetsSourceProvider
```

Change risks:

- Do not introduce Google Maps SDKs or API endpoints.
- Building IDs and asset paths are case-sensitive.
- Map overlays depend on `assets/data/campus_overlay_meta.json` and `assets/maps/overlay_*.png`.
- Route previews can be triggered by query parameters and by Open Day/location actions.

### `features/favorites`

```text
favorites/
├── data/
│   ├── datasources/favorite_building_source.dart
│   └── repositories/favorite_building_repository.dart
├── domain/entities/favorite_building.dart
└── presentation/
    ├── controllers/favorites_controller.dart
    └── widgets/favorite_button.dart
```

Purpose:

- Supabase-backed favorite-building CRUD.
- UI is surfaced through `FavoriteButton` and the `FavoritesPage` currently located under `features/map/presentation/pages/favorites_page.dart`.

Key providers/classes:

- `favoriteBuildingSourceProvider`
- `favoriteBuildingRepositoryProvider`
- `favoritesControllerProvider`
- `FavoriteBuilding`

Tables:

- `favorite_buildings` from migration `20260518000001_create_favorite_buildings.sql`.

Change risks:

- Writes require an anonymous Supabase session.
- Keep favorite state synchronized across buttons and favorites list.

### `features/notifications`

```text
notifications/
├── data/
│   ├── datasources/
│   │   ├── fcm_service.dart
│   │   ├── local_notifications_service.dart
│   │   └── notification_remote_source.dart
│   └── repositories/notification_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── app_notification.dart
│   │   ├── notification_preferences.dart
│   │   └── reminder_request.dart
│   └── services/notification_scheduler.dart
└── presentation/
    ├── controllers/notifications_controller.dart
    ├── pages/notifications_page.dart
    └── widgets/notification_tile.dart
```

Purpose:

- Local notifications.
- Optional FCM token sync.
- Supabase notification inbox and preferences.

Key providers/classes:

- `notificationsControllerProvider`
- `notificationsStreamProvider`
- `unreadNotificationsCountProvider`
- `notificationRepositoryProvider`
- `notificationRemoteSourceProvider`
- `localNotificationsServiceProvider`
- `fcmServiceProvider`
- `notificationSchedulerProvider`

Tables:

- `notifications`
- `notification_preferences`
- `user_fcm_tokens`

Change risks:

- FCM must remain optional enough for local/dev platforms without full Firebase config.
- Notification writes/token sync use Supabase auth and should keep `sessionGuardProvider` behavior.
- Open Day reminder scheduling is local and preference-driven.

### `features/open_day`

```text
open_day/
├── data/
│   ├── open_day_providers.dart
│   └── open_day_reminder_scheduler.dart
├── domain/
│   ├── entities/
│   │   ├── open_day_data.dart
│   │   └── open_day_progress.dart
│   └── services/
│       ├── open_day_gamification.dart
│       ├── open_day_personalisation.dart
│       └── open_day_time.dart
└── presentation/
    ├── pages/
    │   ├── open_day_page.dart
    │   └── your_day_page.dart
    └── widgets/
        ├── bachelor_picker_sheet.dart
        ├── event_actions_sheet.dart
        ├── open_day_home_card.dart
        └── open_day_home_sections.dart
```

Purpose:

- Loads Open Day data from `assets/data/open_day.json`.
- Supports bachelor/interest selection, relevant sessions, general sessions, saved sessions, suggested stops, live status, visit progress, and itinerary.
- Schedules local reminders based on selected preferences.

Key providers:

- `openDayDataProvider`
- `selectedBachelorProvider`
- `relevantOpenDayEventsProvider`
- `degreeSessionsProvider`
- `generalSessionsProvider`
- `suggestedStopsProvider`
- `openDayNowProvider`
- `openDayLiveStatusProvider`
- `savedOpenDayEventsProvider`
- `userDayItemsProvider`
- `locationLiveStatusProvider`
- `visitProgressProvider`
- `openDayReminderSchedulerProvider`

Data dependencies:

- `assets/data/open_day.json`
- `UserPreferences` for bachelor selection, saved event IDs, saved stops, notification settings, reminder lead time, visited location codes.

Change risks:

- `openDayNowProvider` is intentionally injectable/testable.
- Open Day location/building IDs must align with scan trail, building registry, and map IDs.
- Reminder scheduling is local; do not move reminder secrets or server logic into Flutter.

### `features/scan`

```text
scan/
├── data/
│   ├── adapters/
│   │   ├── open_day_schedule_provider_adapter.dart
│   │   ├── registry_location_content_provider.dart
│   │   ├── settings_my_day_api_adapter.dart
│   │   └── settings_progress_api_adapter.dart
│   └── repositories/
│       ├── buildings_repository.dart
│       ├── indoor_repository.dart
│       ├── stamp_catalog_repository.dart
│       └── trail_repository.dart
├── domain/
│   ├── contracts/
│   │   ├── location_content.dart
│   │   ├── my_day_api.dart
│   │   ├── my_day_entry.dart
│   │   ├── progress_api.dart
│   │   ├── schedule_provider.dart
│   │   ├── schedule_slot.dart
│   │   ├── stamp_catalog_entry.dart
│   │   ├── visit_event.dart
│   │   └── visited_state.dart
│   ├── fakes/
│   │   ├── fake_location_content.dart
│   │   ├── fake_my_day_api.dart
│   │   ├── fake_progress_api.dart
│   │   └── fake_schedule_provider.dart
│   ├── models/
│   │   ├── buildings_registry.dart
│   │   ├── indoor_manifest.dart
│   │   └── trail_manifest.dart
│   └── services/
│       ├── scan_branch_lifecycle.dart
│       └── stamp_award_calculator.dart
├── presentation/
│   ├── pages/
│   │   ├── indoor_preview_page.dart
│   │   ├── location_ar_page.dart
│   │   ├── location_card_page.dart
│   │   ├── scan_page.dart
│   │   └── stamps_passport_page.dart
│   └── widgets/
│       ├── card_visit_badge.dart
│       ├── indoor_stop_list.dart
│       ├── indoor_webview.dart
│       ├── location_hero.dart
│       ├── open_day_stops_table.dart
│       ├── photo_gallery.dart
│       ├── scanner_view.dart
│       ├── schedule_chips.dart
│       ├── stamp_earned_sheet.dart
│       └── stamp_progress_ring.dart
└── providers/
    └── scan_providers.dart
```

Purpose:

- QR scanning with `mobile_scanner`.
- Resolves QR/location IDs into location content.
- Shows location cards, schedules, visit state, photos, map/indoor/AR actions.
- Tracks Open Day stamps and visit progress.
- Renders indoor 360-degree previews through Pannellum in WebView.

Key providers:

- `trailRepositoryProvider`
- `trailManifestProvider`
- `indoorRepositoryProvider`
- `buildingsRepositoryProvider`
- `buildingsRegistryProvider`
- `indoorManifestProvider`
- `locationContentProvider`
- `scheduleProvider`
- `myDayApiProvider`
- `visitedStateProvider`
- `progressApiProvider`
- `stampCatalogRepositoryProvider`
- `stampCatalogProvider`

Important rules:

- Visit tracking is by building code when content has a building ID.
- `SettingsProgressApiAdapter` persists progress through `SettingsController`.
- `OpenDayScheduleProviderAdapter` derives live schedule chips from Open Day events.
- Indoor manifest neighbor schema accepts `targetId`/`heading` and legacy `id`/`bearing`.
- Indoor image values already include the `indoor/` path segment.
- Pannellum is served from bundled web assets, not remote CDNs.

Change risks:

- `mobile_scanner` v7 lifecycle matters: own controller, check permission state, do not treat torch as an independent local bool.
- Scanner must pause when the Scan shell branch is inactive.
- Asset entries are non-recursive; keep `assets/data/indoor/` and `assets/web/pannellum/` declared.
- QR IDs, trail manifest IDs, building registry IDs, and Open Day event building codes must stay aligned.

### `features/safety`

```text
safety/
├── data/datasources/safety_poi_source.dart
├── domain/entities/
│   ├── emergency_contact.dart
│   └── safety_poi.dart
└── presentation/
    ├── pages/safety_toolkit_page.dart
    └── widgets/safety_action_card.dart
```

Purpose:

- Emergency call actions.
- Campus security/health contacts.
- AED and first-aid points.
- Torch action.
- Privacy-safe safety messaging.

Change risks:

- Do not automatically share location.
- Phone numbers should be sanitized before launch.
- Torch behavior is device/platform-dependent; keep failures user-safe.

### `features/settings`

```text
settings/
├── data/repositories/settings_repository.dart
└── presentation/
    ├── controllers/settings_controller.dart
    └── pages/settings_page.dart
```

Purpose:

- Owns local `UserPreferences` persistence.
- Drives theme, locale, onboarding, Open Day preferences, notification settings, commute settings, accessibility preferences, visited locations, saved events/stops, and data wipe.

Key providers/classes:

- `settingsControllerProvider`
- `SettingsController`
- `SettingsRepository`
- `LocalSettingsRepository`
- `UserPreferences`

Change risks:

- This is the central local state store. Changes can ripple into router, theme, l10n, notifications, Open Day, scan, map, and transit.
- `SettingsController._save()` should preserve rollback semantics on persistence failure.
- `recordLocationVisit()` is idempotent and normalizes building codes.

### `features/timetable`

```text
timetable/
├── data/repositories/timetable_repository.dart
├── domain/entities/timetable_class.dart
└── presentation/providers/timetable_provider.dart
```

Purpose:

- Stores and loads timetable classes.
- Parses timetable/class JSON or iCal-derived data.
- Exposes next-class provider using injectable `timetableNowProvider`.

Key providers:

- `timetableRepositoryProvider`
- `timetableClassesProvider`
- `timetableNowProvider`
- `nextTimetableClassProvider`

### `features/transit`

```text
transit/
├── domain/entities/
│   ├── metro_departure.dart
│   └── transit_stop.dart
└── presentation/providers/tfnsw_provider.dart
```

Purpose:

- Fetches TfNSW metro departures and stop-search data through Supabase Edge Function proxy.
- Supports commute preferences shown on Home and Settings.

Key providers:

- `tfnswMetroProvider`
- `tfnswStopSearchProvider`

Change risks:

- Edge Function calls depend on Supabase access token / anon auth.
- TfNSW API keys belong server-side in Supabase secrets, not in Flutter.

## 11. Data and Persistence Map

### Local app state

Primary local state model:

```text
lib/shared/models/user_preferences.dart
```

Persistence implementation:

```text
SettingsController
  -> LocalSettingsRepository
     -> SecureStorageService
        -> flutter_secure_storage on mobile
        -> SharedPreferences fallback on desktop/web
```

Local preference areas include:

- Theme mode
- Locale
- Onboarding complete flag
- Reduced motion / high contrast map
- Open Day bachelor/interest selection
- Suggested stops visibility
- Saved Open Day event IDs
- Saved Open Day stop IDs
- Open Day notification settings and reminder lead time
- Visited location/building codes
- Commute stop/mode preferences

### Supabase client use

Supabase initialization:

```text
appInitializationProvider
  -> Supabase.initialize(url: EnvConfig.supabaseUrl, anonKey: EnvConfig.supabaseAnonKey)
  -> auth.signInAnonymously()
```

Write reliability:

```text
sessionGuardProvider
  -> currentSession?
  -> auth.signInAnonymously() when missing
```

Flutter-side Supabase tables referenced:

| Table | Feature | Files |
|---|---|---|
| `app_config` | Building registry | `building_registry_source.dart` |
| `favorite_buildings` | Favorites CRUD | `favorite_building_source.dart` |
| `notifications` | Notification inbox | `notification_remote_source.dart` |
| `notification_preferences` | Notification preferences | `notification_remote_source.dart` |
| `user_fcm_tokens` | Push token sync | `notification_remote_source.dart` |

Supabase functions:

| Function | Path | Role |
|---|---|---|
| `maps-routes` | `supabase/functions/maps-routes/index.ts` | Route proxy and rate limiting |
| `tfnsw-proxy` | `supabase/functions/tfnsw-proxy/index.ts` | TfNSW API proxy |
| `notify` | `supabase/functions/notify/index.ts` | Notification send/sync backend |
| `cleanup-cron` | `supabase/functions/cleanup-cron/index.ts` | Cleanup stale anonymous/backend rows |
| shared CORS | `supabase/functions/_shared/cors.ts` | Edge CORS headers |

Backend tables also exist for older/shared app capabilities in migrations: profiles, units, todos, public events, gamification, audit logs, rate limits, edge response cache, WebAuthn, email/password reset infrastructure, avatar storage, and Open Day stamps. Not every historical table is actively used by the current Flutter UI.

### Asset data

Bundled in `pubspec.yaml`:

```yaml
assets:
  - assets/data/
  - assets/data/indoor/
  - assets/maps/
  - assets/images/
  - assets/photos/
  - assets/stamps/
  - assets/web/
  - assets/web/pannellum/
```

Important asset files:

| Asset | Role |
|---|---|
| `assets/data/buildings.json` | Local/reference building data |
| `assets/data/campus_overlay_meta.json` | Map raster/overlay metadata |
| `assets/data/mq_campus_locations.csv` | Campus location data |
| `assets/data/open_day.json` | Open Day sessions, bachelors, suggested stops |
| `assets/data/open_day_trail.json` | QR trail/location manifest |
| `assets/data/open_day_stamps_catalog.json` | Stamp passport catalog |
| `assets/data/indoor/*.json` | Indoor panorama graph manifests |
| `assets/data/indoor/*.jpg` | Indoor panorama images |
| `assets/maps/mq-campus.png` | Base campus raster |
| `assets/maps/overlay_*.png` | Accessibility, parking, permits, water overlays |
| `assets/images/login_background.png` | Branded splash background |
| `assets/web/indoor_viewer.html` | Pannellum host page |
| `assets/web/pannellum/*` | Vendored Pannellum JS/CSS |
| `assets/tripplanner_v1_swag_efa11_20251002.yml` | Transport API spec/reference |

Asset gotchas:

- Flutter asset directory declarations are non-recursive.
- Asset keys are case-sensitive.
- Verify bundled assets through Flutter build output or AssetManifest when fixing asset-load bugs.

## 12. Security and Privacy Boundaries

Enforced by project convention and `scripts/check.sh`:

- No analytics/tracking packages.
- No Google Maps SDK or API usage.
- No login/signup routes or `signInWithPassword`.
- No stale `mq_navigation` package references in Dart/YAML/ARB source.
- No obvious hardcoded secret key patterns in `lib`, `test`, or `scripts`.

Sensitive boundaries:

- API service keys belong in Supabase Edge Function secrets only.
- Flutter may contain public Supabase anon config, but not service-role keys.
- Location is used ephemerally for map/navigation and is not persisted as history.
- Safety actions must not automatically share location.
- Edge Functions perform server-side calls to external services such as OpenRouteService/TfNSW.

## 13. Tests Map

Test layout mirrors source areas:

```text
test/
├── app/                             # Theme, route names, shell behavior
├── core/                            # Env config, exceptions, connectivity, session guard, result, haptics
├── features/
│   ├── auth/                        # Auth service/repository/controller
│   ├── favorites/                   # Favorite entity/source/controller/page/button
│   ├── home/                        # Home and onboarding pages
│   ├── map/                         # Building, search, projection, routes, map UI, widgets
│   ├── notifications/               # Scheduler, smoke, notification tile
│   ├── open_day/                    # Asset, time, personalization, gamification, reminders, widgets
│   ├── safety/                      # Safety toolkit page/flows
│   ├── scan/                        # Adapters, contracts, fakes, models, pages, repos, services, widgets
│   ├── settings/                    # Controller, repository, settings page, stamps tile
│   ├── timetable/                   # Timetable class/repository/providers
│   └── transit/                     # Stop model, dedupe, TfNSW provider
├── shared/                          # Shared MQ widgets
└── widget_test.dart                 # Smoke test
```

Current feature test counts:

| Test area | Files |
|---|---:|
| `scan` | 24 |
| `map` | 20 |
| `open_day` | 7 |
| `favorites` | 5 |
| `settings` | 4 |
| `auth` | 3 |
| `notifications` | 3 |
| `timetable` | 3 |
| `transit` | 3 |
| `home` | 2 |
| `safety` | 1 |

High-value test targets when changing behavior:

- Router or bottom nav: `test/app/router/app_shell_test.dart`, `test/app/route_names_test.dart`
- Map selection/routing: `test/features/map/*`
- Scan lifecycle and card behavior: `test/features/scan/pages/*`, `test/features/scan/services/*`
- Indoor manifests: `test/features/scan/models/indoor_manifest_test.dart`, `test/features/scan/repositories/indoor_repository_test.dart`
- Settings persistence: `test/features/settings/settings_controller_test.dart`, `settings_repository_test.dart`
- Open Day recommendations/reminders: `test/features/open_day/*`
- Supabase write flows: controller/repository tests plus `test/core/network/session_guard_test.dart`

## 14. CI / Quality Gate

Primary command:

```bash
./scripts/check.sh
```

Useful variants:

```bash
./scripts/check.sh --quick
./scripts/check.sh --fix
./scripts/check.sh --verbose
./scripts/check.sh --quick --fix
```

Gate steps:

1. `flutter pub get`
2. `dart format --set-exit-if-changed` over existing source/test/tool/script dirs, or `dart format` with `--fix`
3. `flutter analyze --no-fatal-infos`
4. `flutter test --coverage`
5. Coverage floor check: 50 percent line coverage excluding generated code
6. `flutter gen-l10n`
7. Untranslated l10n report check, non-blocking when tracked
8. Privacy guard for forbidden analytics/tracking packages
9. Secret scan for obvious hardcoded API key patterns in `lib`, `test`, `scripts`
10. No stale `mq_navigation` package-name references in source/config checked by the guard
11. No login route/password-auth guard
12. No Google Maps guard
13. `flutter build apk --debug`, skipped by `--quick`

Logs are written to `.dart_tool/check_logs/`.

## 15. Documentation Map

```text
docs/
├── ARCHITECTURE.md                  # Architecture overview; may lag code if not updated
├── SECURITY_POSTURE.md              # Privacy/security model
├── endpoint_inventory.md            # API/endpoint inventory
├── entity_inventory.md              # Supabase entities and shared schema
├── env_inventory.md                 # Env and dart-define inventory
├── key_inventory.md                 # Key/secrets inventory
├── map_inventory.md                 # Map/building/overlay details
├── notification_matrix.md           # Notification types and channels
├── route_matrix.md                  # Route table/deep link inventory
└── superpowers/rename-coordination.md
```

`REPO_MAP.md` should be treated as the practical orientation map. The `docs/` files are useful deeper references, but some may lag current code after fast feature work.

## 16. Platform Host Projects

| Directory | Role |
|---|---|
| `android/` | Android app host, Gradle/Kotlin, Fastlane |
| `ios/` | iOS app host, Podfile/Fastlane |
| `macos/` | macOS host project for desktop dev |
| `linux/` | Linux host project |
| `windows/` | Windows host project |
| `web/` | Web host files, manifest, icons, bootstrap |

Platform gotchas:

- Android package path still includes legacy `io/mqnavigation/...`; the no-stale-name guard intentionally excludes native build IDs where legacy namespace may remain for compatibility.
- macOS desktop runs can warn because Firebase/Supabase/ObjectBox-style mobile assumptions may not all be configured locally.
- Generated platform plugin registrant files are normal Flutter output and should not be hand-edited.

## 17. Common Change Playbooks

### Add or change a route

1. Update `lib/app/router/route_names.dart`.
2. Update `lib/app/router/app_router.dart`.
3. If it is a bottom tab, update `ShellBranchIndex` and `AppShell`.
4. Add/adjust router tests in `test/app/`.
5. Check deep links if the route can be opened externally.

### Add a new Open Day data field

1. Update `assets/data/open_day.json`.
2. Update entities in `open_day/domain/entities/open_day_data.dart`.
3. Update relevant providers in `open_day/data/open_day_providers.dart`.
4. Update Scan adapters if the field surfaces on location cards.
5. Add/adjust asset and provider tests.

### Add an indoor building preview

1. Add `assets/data/indoor/<building-id>.json`.
2. Add referenced panorama images under `assets/data/indoor/`.
3. Ensure building ID/case matches registry/trail data.
4. Confirm `pubspec.yaml` still includes `assets/data/indoor/`.
5. Add/adjust `indoor_manifest` and repository tests.
6. Verify WebView loads through `IndoorPreviewPage` / `IndoorWebView`.

### Change QR scan behavior

1. Read `scan_branch_lifecycle.dart`, `scan_page.dart`, and `scanner_view.dart`.
2. Preserve camera pause/resume behavior for inactive shell branches.
3. Keep `mobile_scanner` v7 controller lifecycle rules.
4. Update location card, visit, and stamp tests as needed.

### Add a Supabase write path

1. Keep service-role secrets out of Flutter.
2. Use `sessionGuardProvider` before writes.
3. Add/verify RLS migration.
4. Add repository/controller tests with injectable seams.
5. Confirm privacy/secret guards pass.

### Add a local preference

1. Add the field to `UserPreferences`.
2. Add storage key and load/save logic in `settings_repository.dart`.
3. Add controller method in `settings_controller.dart`.
4. Update UI in `settings_page.dart` if user-facing.
5. Add repository/controller tests.

### Add a translatable string

1. Add key to `lib/app/l10n/app_en.arb`.
2. Add reasonable translations or allow untranslated report if intentionally staged.
3. Run `flutter gen-l10n`.
4. Update widget tests if visible strings are asserted.

## 18. Known Guardrails and Gotchas

- Do not add login/signup/password-auth flows.
- Do not add Google Maps dependencies or Google Maps endpoint usage.
- Do not add analytics, telemetry, crash-reporting, or tracking SDKs.
- Do not store external API secrets in Flutter or checked-in config.
- Use MQ theme tokens rather than ad hoc colors, typography, or spacing.
- Use Riverpod provider seams for testability instead of static/global coupling.
- Treat `UserPreferences` changes as cross-feature changes.
- Keep route names centralized in `RouteNames`.
- Keep bottom-tab order centralized in `ShellBranchIndex`.
- Asset directories are non-recursive; declare each subdirectory.
- Case-sensitive asset names matter on device even when local development is forgiving.
- Generated l10n files are output; edit ARB files, then regenerate.
- Supabase migrations are shared backend history; avoid creating Flutter-only schema assumptions.

## 19. Fast Orientation Index

| Question | Start here |
|---|---|
| How does the app boot? | `lib/main.dart`, `lib/app/bootstrap/`, `lib/app/mq_journey_app.dart` |
| Where are routes? | `lib/app/router/app_router.dart`, `route_names.dart` |
| Where is bottom navigation? | `lib/app/router/app_shell.dart`, `ShellBranchIndex` |
| Where is theme? | `lib/app/theme/` |
| Where are translations? | `lib/app/l10n/app_en.arb` and generated output |
| Where are preferences stored? | `lib/shared/models/user_preferences.dart`, `settings_repository.dart` |
| Where is anonymous auth guarded? | `lib/core/network/session_guard.dart` |
| Where is the campus map? | `lib/features/map/` |
| Where is route fetching? | `maps_routes_remote_source.dart`, `supabase/functions/maps-routes/` |
| Where is QR scanning? | `lib/features/scan/presentation/pages/scan_page.dart`, `scanner_view.dart` |
| Where are location cards? | `lib/features/scan/presentation/pages/location_card_page.dart` |
| Where is indoor preview? | `indoor_preview_page.dart`, `indoor_webview.dart`, `assets/web/indoor_viewer.html` |
| Where are Open Day sessions? | `assets/data/open_day.json`, `open_day_providers.dart` |
| Where are stamps? | `open_day_stamps_catalog.json`, `stamp_catalog_repository.dart`, `stamps_passport_page.dart` |
| Where are favorites? | `lib/features/favorites/`, `features/map/presentation/pages/favorites_page.dart` |
| Where are notifications? | `lib/features/notifications/`, `supabase/functions/notify/` |
| Where is safety toolkit? | `lib/features/safety/` |
| Where is TfNSW transit? | `lib/features/transit/`, `supabase/functions/tfnsw-proxy/` |
| Where are backend migrations? | `supabase/migrations/` |
| What command proves the repo? | `./scripts/check.sh` |
