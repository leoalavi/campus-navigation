# MQ Journey: Technical Architecture (2026)

## Overview
Feature-First Clean Architecture for high-concurrency campus navigation, transit data, compass mode, and safety toolkit. Privacy by design: no account needed, zero tracking, zero location history.

## Directory Structure

```
lib/
├── app/
│   ├── bootstrap/          → App init, Supabase + Firebase setup
│   ├── l10n/               → ARB files (35 locales) + generated localisations
│   ├── router/             → GoRouter config (StatefulShellRoute, 4 tabs)
│   └── theme/              → MQ design tokens (MqColors, MqTypography, MqSpacing)
├── core/
│   ├── config/             → Env vars via --dart-define
│   ├── error/              → App exceptions, error boundary
│   ├── logging/            → Structured logger
│   ├── network/            → Connectivity service
│   ├── security/           → Flutter secure storage
│   └── utils/              → Result type, validators, haptics
├── shared/
│   ├── extensions/         → BuildContext extensions (theme, dark mode, snackbar)
│   ├── models/             → UserPreferences
│   └── widgets/            → MqButton, MqCard, MqInput, MqBottomSheet, GlassPane
└── features/
    ├── auth/               → Supabase anonymous auth (silent sign-in on launch)
    ├── favorites/          → Building favorites CRUD (controller, repository, datasource, UI)
    ├── deep_link/          → Syllabus Sync deep link contract
    ├── home/               → Welcome dashboard, onboarding, metro countdown
    ├── map/                → Campus map (161 buildings, illustrated renderer, routing, compass)
    ├── notifications/      → FCM push + local study prompts
    ├── open_day/           → Open Day event browsing & reminders
    ├── safety/             → Campus Safety Toolkit (flashlight, contacts, first aid, AED)
    ├── settings/           → Theme, locale, commute, notifications, data, privacy badge
    ├── timetable/          → Unit & class schedule management
    └── transit/            → Metro/bus/train stop search & commute prefs
```

## Layering Strategy

### Presentation Layer (Riverpod)
- **Controllers**: `MapController`, `SettingsController`, `NotificationsController`, `AuthController`, `FavoritesController`
- **Widgets**: Atomic design (`MqButton`, `MqCard`, `SafetyActionCard`) + feature-specific views
- **Compass**: `CompassModeView` — real-time heading via `flutter_compass`, `AnimatedRotation`, heading accuracy bar

### Domain Layer (Pure Dart)
- **Entities**: `Building`, `MapRoute`, `NavInstruction`, `SafetyPoi`, `EmergencyContact`, `LocationSample`, `FavoriteBuilding`
- **Services**: `GeoUtils`, `MapPolylineCodec`, `OfflineMapsService`

### Data Layer
- **Repositories**: `MapRepositoryImpl`, `SettingsRepository`, `AuthRepository`, `FavoriteBuildingRepository`
- **Data Sources**: `MapsRoutesRemoteSource` (Supabase Edge Functions), `SafetyPoiSource` (curated campus data), `SecureStorageService`, `FavoriteBuildingRemoteSource`
- **Location**: `LocationSource` (GPS + last-known fallback, Android emulator mock rejection)

## Navigation & Routing (GoRouter 17.x)

```
StatefulShellRoute.indexedStack (4 tabs + standalone routes)
├── /home                  → HomePage (dashboard)
├── /map                   → MapPage (illustrated campus map, building search, route panel)
├── /favorites             → FavoritesPage (list of bookmarks)
├── /settings              → SettingsPage (privacy badge, commute, data, danger zone)
├── /safety                → SafetyToolkitPage (standalone, no auto location)
├── /notifications         → NotificationsPage (covers shell)
├── /open-day              → OpenDayPage (temporal feature)
├── /onboarding            → OnboardingPage (first-launch gate)
└── /open                  → Deep link router (Syllabus Sync)
```

## Key Features

### Campus Map
- **Campus Map** (`flutter_map` + `CrsSimple`): custom raster calibrated to MQ GPS coordinates
- **Routing**: Supabase Edge Functions (OpenRouteService + TfNSW), 4 travel modes
- **Compass Mode**: `flutter_compass` 0.8 stream, bearing-to-destination calculation, `AnimatedRotation` smooth heading, heading accuracy display, privacy-safe (all on-device)

### Campus Safety Toolkit
- Flashlight toggle (via `torch_light`)
- Emergency contacts: 000, Campus Security, Health Service, 1800 CRISIS (localized tap-to-dial via `url_launcher`)
- 3 first aid + 5 AED locations with building codes and descriptions
- Security shuttle info + call button
- Privacy banner: "Your location is never shared automatically"
- **Zero automatic location sharing** — user manually calls or navigates

### Privacy by Design
- **No account required** — app uses silent anonymous session, favourites and notifications work out of the box
- No analytics/tracking packages (enforced by `check.sh` privacy guard)
- Preferences stored locally via `SharedPreferences` + `FlutterSecureStorage`
- No location history, no telemetry, no crash reporting
- Settings page shows permanent **Privacy Badge**: "Private by design: no account, no tracking, no location history"

## CI / Validation (`scripts/check.sh`)
```
12 steps:
  1. flutter pub get
  2. dart format (--fix available)
  3. flutter analyze (single-pass, --no-fatal-infos)
  4. flutter test (295 tests)
  5. flutter gen-l10n
  6. untranslated l10n check (non-blocking)
  7. privacy guard (blocks analytics packages)
  8. secret scan (hardcoded API keys in lib/test/scripts)
  9. no-stale-name guard (blocks mq_navigation references)
 10. no-login-route guard (ensures no /auth routes exist)
 11. no-google guard (blocks Google Maps SDK/files references)
 12. flutter build apk --debug (skipped with --quick)
```
Supports `--quick`, `--fix`, `--verbose` flags. Structured logs under `.dart_tool/check_logs/`.

## Dependencies (Key)
- **State**: `flutter_riverpod` 3.2 | **Router**: `go_router` 17
- **Maps**: `flutter_map` 8.2
- **Backend**: `supabase_flutter` 2.8 (Auth, DB, Realtime)
- **Location**: `geolocator` 14 | **Compass**: `flutter_compass` 0.8
- **Safety**: `torch_light` 1.1 | **Links**: `url_launcher` 6.3
- **i18n**: `flutter_localizations` / `intl` (35 ARB locales, RTL for ar/fa/he/ur)

## Supporting Documentation

Detailed inventories live alongside this file in `docs/`:

| File | What it covers |
|------|---------------|
| `endpoint_inventory.md` | API routes, Edge Functions, and web-only endpoints |
| `entity_inventory.md` | Shared Supabase schema (profiles, units, events, notifications, RPCs) |
| `env_inventory.md` | All `--dart-define` variables and Supabase Edge Function secrets |
| `key_inventory.md` | API keys, service accounts, and where they're used |
| `map_inventory.md` | Building registry, overlay layers, and map renderer specifics |
| `notification_matrix.md` | Notification types, triggers, and delivery channels |
| `route_matrix.md` | GoRouter route table and deep link mapping |
