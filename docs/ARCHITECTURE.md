# Campus Navigation: Technical Architecture (2026)

## Overview
Feature-first Flutter architecture for campus navigation, transit data, compass mode, and safety features. The current router has no login UI. Location is sent for requested routing and nearby transport; the app does not offer location-history tracking.

## Directory Structure

```
lib/
├── app/
│   ├── bootstrap/          → App init, Supabase + Firebase setup
│   ├── l10n/               → ARB files (35 locales) + generated localisations
│   ├── router/             → GoRouter config (3 visible tabs; optional Scan branch)
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
    ├── auth/               → Legacy/auth support code; no current login route
    ├── favorites/          → Building favorites CRUD (controller, repository, datasource, UI)
    ├── deep_link/          → Syllabus Sync deep link contract
    ├── home/               → Welcome dashboard, onboarding, metro countdown
    ├── map/                → Campus map (161 buildings, dual renderer, routing, compass)
    ├── notifications/      → Local study prompts and optional FCM support code
    ├── open_day/           → Open Day event browsing & reminders
    ├── safety/             → Campus Safety Toolkit (flashlight, contacts, first aid, AED)
    ├── settings/           → Theme, locale, commute, notifications, data, privacy badge
    ├── timetable/          → Unit & class schedule management
    └── transit/            → Metro/bus/train stop search & commute prefs
```

## Layering Strategy

### Presentation Layer (Riverpod)
- **Controllers**: Map, settings, notifications and favourites controllers
- **Widgets**: Atomic design (`MqButton`, `MqCard`, `SafetyActionCard`) + feature-specific views
- **Compass**: `CompassModeView` — real-time heading via `flutter_compass`, `AnimatedRotation`, heading accuracy bar

### Domain Layer (Pure Dart)
- **Entities**: `Building`, `MapRoute`, `NavInstruction`, `SafetyPoi`, `EmergencyContact`, `LocationSample`, `FavoriteBuilding`
- **Services**: `GeoUtils`, `MapPolylineCodec`, `OfflineMapsService`

### Data Layer
- **Repositories**: Map, settings and favourite-building repositories; auth support code remains in the tree
- **Data Sources**: `MapsRoutesRemoteSource` (Supabase Edge Functions), `SafetyPoiSource` (curated campus data), `SecureStorageService`, `FavoriteBuildingRemoteSource`
- **Location**: `LocationSource` (GPS + last-known fallback, Android emulator mock rejection)

## Navigation & Routing (GoRouter 17.x)

```
StatefulShellRoute.indexedStack (Home, Map, Scan branch, Settings; Scan is opt-in)
├── /home                  → HomePage (dashboard)
├── /map                   → MapPage (dual renderer, building search, route panel)
├── /scan                  → ScanPage (Open Day branch)
├── /settings              → SettingsPage (privacy badge, commute, data, danger zone)
├── /favorites             → FavoritesPage (standalone bookmarks page)
├── /safety                → SafetyToolkitPage (standalone, no auto location)
├── /notifications         → NotificationsPage (covers shell)
├── /open-day              → OpenDayPage (temporal feature)
├── /onboarding            → OnboardingPage (first-launch gate)
└── /open                  → Deep link router (Syllabus Sync)
```

## Key Features

### Campus Map (Dual-Renderer)
- **Google Maps** (`google_maps_flutter` 2.15): traffic, map-type, clustering, bearing camera
- **Campus Map** (`flutter_map` + `CrsSimple`): custom raster calibrated to MQ GPS coordinates
- **Routing**: Supabase Edge Functions (Google Routes API + Directions API fallback), 4 travel modes
- **Compass Mode**: `flutter_compass` 0.8 stream, bearing-to-destination calculation, `AnimatedRotation` smooth heading, heading accuracy display, privacy-safe (all on-device)

### Campus Safety Toolkit
- Flashlight toggle (via `torch_light`)
- Emergency contacts: 000, Campus Security, Health Service, 1800 CRISIS (localized tap-to-dial via `url_launcher`)
- 3 first aid + 5 AED locations with building codes and descriptions
- Security shuttle info + call button
- Privacy banner: "Your location is never shared automatically"
- **Zero automatic location sharing** — user manually calls or navigates

### Privacy by Design
- **No login UI in the current router** (legacy auth code remains in the repository)
- No analytics/tracking packages currently bundled; the local `check.sh` script has a privacy guard, but CI does not invoke it
- Preferences stored locally via `SharedPreferences` + `FlutterSecureStorage`
- No app location-history feature or analytics package; coordinates leave the device for requested routes and nearby transport
- Settings page describes the current no-account privacy model

## Local validation (`scripts/check.sh`)
```
9 steps:
  1. flutter pub get
  2. dart format (--fix available)
  3. flutter analyze (single-pass, --no-fatal-infos)
  4. flutter test (765 passing locally on 4 November 2026)
  5. flutter gen-l10n
  6. untranslated l10n check (non-blocking)
  7. privacy guard (blocks analytics packages)
  8. secret scan (hardcoded API keys in lib/test/scripts)
  9. flutter build apk --debug (skipped with --quick)
```
Supports `--quick`, `--fix`, `--verbose` flags. Structured logs under `.dart_tool/check_logs/`.

GitHub Actions uses `.github/workflows/ci.yml` instead of invoking this script. It checks formatting, analysis, tests and Edge Function types, then builds Android, iOS, macOS, Windows and web on `main` pushes. The local privacy and secret-scan steps above are not currently CI gates.

## Dependencies (Key)
- **State**: `flutter_riverpod` 3.2 | **Router**: `go_router` 17
- **Maps**: `google_maps_flutter` 2.15 + `flutter_map` 8.2
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
| `key_inventory.md` | Localisation key inventory |
| `map_inventory.md` | Building registry, overlay layers, and map renderer specifics |
| `notification_matrix.md` | Notification types, triggers, and delivery channels |
| `route_matrix.md` | GoRouter route table and deep link mapping |
