<div align="center">

<!-- Typing animation -->
[![Typing SVG](https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=700&size=20&duration=2800&pause=700&color=0067a5&center=true&vCenter=true&width=860&lines=Find+Your+Way+Around+Macquarie+%E2%80%94+Without+Selling+Your+Data;Illustrated+Campus+Map+%E2%80%A2+Compass+Mode+%E2%80%A2+Routing;Flutter+3.41+%E2%80%A2+Riverpod+3+%E2%80%A2+Supabase+%E2%80%A2+35+Languages;Privacy+by+Design+%E2%80%A2+295+Tests+%E2%80%A2+Open+Day+2026+Ready)](https://readme-typing-svg.demolab.com)

<!-- Badges -->
![License: MIT](https://img.shields.io/badge/License-MIT-f59e0b?style=for-the-badge)
![Flutter](https://img.shields.io/badge/Flutter_3.41+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart_3-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Riverpod](https://img.shields.io/badge/Riverpod_3.2-7C3AED?style=for-the-badge)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Tests](https://img.shields.io/badge/295_Tests-Flutter_Test-6E9F18?style=for-the-badge)
![Material 3](https://img.shields.io/badge/Material_3-757575?style=for-the-badge&logo=materialdesign&logoColor=white)

</div>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

# MQ Journey — Macquarie University Open Day Companion

> **Find your way around Macquarie — without selling your data.**

A production-ready Open Day campus companion for Macquarie University visitors — with an illustrated campus map, personalised sessions, indoor previews, transit countdowns, and 35-language i18n. **Privacy by design: no account needed, zero tracking, no location history.**

Part of a **two frontends, one backend** architecture sharing a Supabase backend with the companion Next.js web application. MQ Journey is built specifically for the **Macquarie University Open Day** visitor experience.

**[📖 Project Report](PROJECT_REPORT.md)** &nbsp;·&nbsp; **[📸 Screenshots](screenshots/)** &nbsp;·&nbsp; **[🏗️ Architecture](docs/ARCHITECTURE.md)** &nbsp;·&nbsp; **[🔐 Security Posture](docs/SECURITY_POSTURE.md)**

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## 📌 For Markers — Quick Start

| Step | Action |
|------|--------|
| 1 | `flutter pub get && flutter gen-l10n` |
| 2 | Copy `.env.example` → `.env`. The repo ships with a working Supabase test project anon key — no setup needed for graders. |
| 3 | `flutter run --dart-define-from-file=.env` (Android emulator or Chrome) |
| 4 | Tap a building → ❤️ to favourite. Visit the **Favourites** tab to Edit (note) and Delete (kebab menu). |

### Where to find each rubric requirement

| Requirement | Where it lives |
|-------------|---------------|
| **Remote database (Supabase)** | `favorite_buildings`, `notifications`, `notification_preferences` tables; `lib/features/favorites/data/` and `lib/features/notifications/data/` |
| **CRUD on a data entity** | Favourites: **Create** via ❤️ on any building, **Read** on the Favourites tab, **Update** via the kebab → Edit note, **Delete** via swipe or kebab → Remove |
| **Mobile device service** | `geolocator` (GPS), `flutter_compass` (heading), `torch_light` (flashlight) — all in `lib/features/map/` and `lib/features/safety/` |
| **Widget tests** | `test/features/*/` — 50+ widget tests, including 10 for the Favourites page with full interaction coverage |
| **Unit tests** | 240+ unit tests across map, auth, favourites, notifications, settings, transit, open day |
| **Project Report / Essay** | [`PROJECT_REPORT.md`](PROJECT_REPORT.md) — 820-word essay addressing the required questions (app description, core features, audience personas, competitor advantages, technical credentials, and layout) |

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## 🎯 High-Level Impact & Value Proposition

Existing campus maps either stop at the kerb (Google/Apple Maps don't know which door is *18 Wally's Walk*) or require single sign-on for a poor-quality web experience. MQ Journey solves this by providing:

- **Illustrated Campus Map:** Single flutter_map + CrsSimple raster renderer with calibrated building position overlay — pinpoints the correct **building entrance**, not the road.
- **Turn-by-Turn Routing:** Server-side routing via Supabase Edge proxy (OpenRouteService + TfNSW) with walking, driving, cycling, and transit modes. Arrival detection, off-route recalculation, and a collapsible nav sheet that doesn't stop navigation.
- **Privacy-by-Design Architecture:** No account needed, **zero analytics packages** (CI-enforced), no location history, on-device compass calculation. Encryption via Keychain / Android Keystore.
- **Open Day Ready:** Branded study-interest picker, dynamic event cards, BuildingActionsSheet shared with [Syllabus Sync](https://github.com/mrpouyaalavi/syllabus-sync) deep-link contract.

<br/>

## Why This Project Matters

Most campus apps are dated, English-only, and trade student data for the convenience of a "free" Google Maps embed. MQ Journey was built to prove three things:

1. **A privacy-respecting campus app is technically achievable.** Real GPS, real routing, real building markers, real safety contacts — and zero analytics SDKs. The CI privacy guard refuses to compile the app if any tracking package is added.
2. **Localisation can be a first-class concern, not an afterthought.** 35 ARB locales with full RTL support for Arabic, Farsi, Hebrew, and Urdu. Tested on real screens, not just `flutter gen-l10n` output.
3. **Two frontends, one backend** is a credible architecture. The same Supabase project powers this Flutter client and the Syllabus Sync Next.js platform — sharing data models, auth users, and Edge Functions without forcing a single UI.

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## Screenshots

<div align="center">

| Home | Map |
|:---:|:---:|
| <img width="320" alt="Home" src="screenshots/02_home_page.png"/> | <img width="320" alt="Map" src="screenshots/03_map_page.png"/> |

| Favourites | Safety |
|:---:|:---:|
| <img width="320" alt="Favourites" src="screenshots/05_favorites_page.png"/> | <img width="320" alt="Safety" src="screenshots/04_safety_page.png"/> |

| Notifications | Settings |
|:---:|:---:|
| <img width="320" alt="Notifications" src="screenshots/06_notifications_page.png"/> | <img width="320" alt="Settings" src="screenshots/07_settings_page.png"/> |

</div>

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## Key Features

```text
╔══════════════════════════════════════════════════════════════════════╗
║  🗺  flutter_map + CrsSimple illustrated campus renderer             ║
║  🧭  On-device compass mode with bearing-to-destination arrow        ║
║  🛣  ORS campus / TfNSW transit routing via Supabase Edge            ║
║  ❤️  Favourites CRUD: heart-toggle, edit-note, swipe-to-delete       ║
║  🚨  Campus Safety Toolkit: 000, AEDs, first aid, shuttle, torch     ║
║  🚆  Live Macquarie Uni metro countdown via TfNSW Open Data proxy    ║
║  🌍  35 locales · Full RTL for ar/fa/he/ur · WCAG-aware semantics    ║
║  🔐  No login · Zero analytics · CI-enforced privacy guard            ║
║  ⚡  295 tests · 0 analyzer issues · 12-step quality gate script       ║
╚══════════════════════════════════════════════════════════════════════╝
```

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## 🏗️ Technical Architecture Overview

MQ Journey is built on a modern Flutter stack designed for offline resilience, type safety, and zero-trust privacy.

### System Architecture

```mermaid
graph TD
    A[Flutter Mobile Client] -->|HTTPS/WSS| B(Supabase Backend)
    C[Next.js Web Client] -->|HTTPS/WSS| B

    subgraph "Supabase"
        B --> D[(Postgres + RLS)]
        B --> E[Realtime]
        B --> F[Edge Functions]
    end

    subgraph "External APIs"
        F --> G[OpenRouteService]
        F --> H[TfNSW Open Data]
    end
```

### Runtime Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter 3.41+ (Stable channel) |
| **State** | Riverpod 3.2 (AsyncNotifier) |
| **Routing** | GoRouter 17.1 (StatefulShellRoute, 4 tabs + standalone routes) |
| **Maps** | flutter_map 8.3 + CrsSimple raster |
| **Backend** | Supabase (Postgres, RLS, Realtime, Deno Edge Functions) |
| **Location** | geolocator 14 (raw GPS + last-known fallback, emulator mock rejection) |
| **Compass** | flutter_compass 0.8 |
| **Notifications** | Firebase Messaging + flutter_local_notifications 21 |
| **i18n** | flutter_localizations + intl — 35 ARB locales, RTL for ar/fa/he/ur |
| **Security** | flutter_secure_storage 10 (iOS Keychain / Android Keystore) |

### Key Architectural Decisions

- **Defensive bootstrap with timeouts:** `Firebase.initializeApp()` and `Supabase.initialize()` are both wrapped in `.timeout()` calls so the app cannot hang on a stalled network during cold start (root cause we hit during Release-mode testing).
<!-- Silent existing-user detection removed with login gate -->
- **Building actions sheet:** `BuildingActionsSheet` offers two choices — "View on Campus Map" (marker only) and "Navigate" (route preview auto-loaded via `?preview=route` query parameter).
- **CI privacy guard:** `scripts/check.sh` refuses to compile if any analytics package (`firebase_analytics`, `google_analytics`, `appsflyer`, `amplitude`, `mixpanel`, `segment`, `sentry_flutter`, `facebook_app_events`) is added to `pubspec.yaml`.

> **Deep Dive:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · [`docs/SECURITY_POSTURE.md`](docs/SECURITY_POSTURE.md) · [`docs/route_matrix.md`](docs/route_matrix.md)

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## 🔒 Privacy Posture & Hardening

Privacy is a structural constraint, not a feature flag. Every line of code is audited against the **privacy-by-default** principle below.

| Principle | Enforcement |
|-----------|------------|
| No account required | Auth is fully removed — app uses a silent anonymous session. Favourites and notifications work without any user action. |
| Zero tracking | No analytics, telemetry, or crash reporting packages. CI guard blocks them at PR time. |
| No location history | GPS used ephemerally — never persisted, never transmitted to any external service. |
| Local-only preferences | Theme, locale, commute mode, and quiet hours stored via `SharedPreferences` + `FlutterSecureStorage`. |
| Safety privacy | Emergency contacts use tap-to-dial — location is **never automatically shared**. |
| Compass privacy | All heading calculation happens on-device. No data leaves the phone. |

> **Defence-in-depth model:** [`docs/SECURITY_POSTURE.md`](docs/SECURITY_POSTURE.md) · [`docs/key_inventory.md`](docs/key_inventory.md)

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## Who is this for?

We designed MQ Journey around four real user personas — the people we'd hand a phone to on Open Day and watch them use it.

| Persona | Goals | Why this app over competitors |
|---------|-------|------------------------------|
| **"Open Day Olivia"** — Year 12 prospective student visiting campus for the first time. | Find the Faculty of Arts building, the Library, and where her parents parked. Pin places to return to. | Built-for-Macquarie illustrated campus map with 161 named buildings — Google Maps shows roads, not which door is *18 Wally's Walk*. |
| **"Commuter Chen"** — First-year domestic student catching the Metro from Tallawong. | Know if he's late for his 9am tutorial. Find the nearest defibrillator if a friend collapses at the gym. | Live Macquarie Uni metro countdown on the home screen + the Safety Toolkit one tap away. No other campus app surfaces both. |
| **"International Isha"** — New PhD student from Mumbai, navigating campus in her second language. | Read the app in Hindi or English. Save the rooms her supervisor mentioned. | Full 35-language i18n (with RTL for Arabic, Farsi, Hebrew, Urdu) — most campus apps are English-only. |
| **"Accessibility Alex"** — Low-vision student who uses a screen reader. | High-contrast map mode, no flashing animations, predictable navigation. | Reduced-motion toggle, high-contrast map mode, semantic widgets throughout, no analytics/tracking SDKs. |

**Why pick MQ Journey over Google/Apple Maps?** Google Maps stops at the street. We start at the building entrance — and we promise to never sell where you walked.

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## Device Compatibility

| Platform | Status | Notes |
|----------|--------|-------|
| **Android emulator** (API 33+) | ✅ Full | All features verified. Recommended for marking. |
| **Android physical device** | ✅ Full | Compass, flashlight, GPS, push notifications all functional. |
| **Chrome (web)** | ✅ Core | Auth, favourites CRUD, maps, routing, transit countdown work. Compass mode and flashlight gracefully degrade — the UI displays an "unsupported on this device" fallback. |
| **iOS device** | ✅ Full | Native build verified on iPhone (iOS 17+). Custom URL scheme `io.mqjourney://` registered for deep linking (legacy `io.mqnavigation://` also supported during transition). |
| **macOS desktop** | ✅ Core | Location and flutter_map campus renderer functional. CFBundleURLTypes registered for deep linking support. |

If a platform-specific issue surfaces during marking, the relevant feature renders a typed `MapStateError` fallback rather than crashing.

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## Repository Layout

```text
lib/
├── app/              Bootstrap, router, theme, l10n (35 ARB locales)
├── core/             Config, error handling, logging, networking, security
├── shared/           Extensions, models, widgets (MqButton, MqCard, MqInput)
└── features/
    ├── auth/         Supabase anonymous auth (silent sign-in on launch)
    ├── favorites/    Building favourites CRUD (controller, repo, datasource, UI)
    ├── home/         Welcome dashboard, onboarding, metro countdown
    ├── map/          flutter_map campus, routing, compass mode, search, favourites
    ├── safety/       Safety toolkit, emergency contacts, first aid / AED
    ├── notifications/ FCM push, local reminders, inbox
    ├── open_day/     Open Day events, study interest, reminders
    ├── settings/     Preferences, privacy badge, data wipe
    ├── transit/      Metro/bus/train search, commute prefs
    ├── timetable/    Unit and class schedule management
    └── deep_link/    Syllabus Sync deep link contract

test/                 295 widget & unit tests (Flutter Test suite)
supabase/             Edge Functions (maps-routes, tfnsw-proxy)
docs/                 9 reference documents (architecture, security, inventories)
screenshots/          6 screen captures used in this README
scripts/              run.sh, check.sh (quality gate)
```

> **Full Inventory:** [`docs/map_inventory.md`](docs/map_inventory.md) · [`docs/endpoint_inventory.md`](docs/endpoint_inventory.md) · [`docs/entity_inventory.md`](docs/entity_inventory.md)

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## Quick Start

### Prerequisites
- Flutter `3.11+` ([install guide](https://docs.flutter.dev/get-started/install))
- Android SDK / Xcode (for device builds)
- A Supabase project with the [`maps-routes`](supabase/functions/maps-routes/) Edge Function

### Setup
```bash
# Clone and install
git clone <repo-url>
cd MQ-Journey
flutter pub get

# Configure environment
cp .env.example .env
# Edit .env with your Supabase credentials
# (see docs/env_inventory.md for the full variable list)

# Generate localisations
flutter gen-l10n

# Run the app
flutter run --dart-define-from-file=.env
# Or via convenience script:
./scripts/run.sh
```

### Quality Assurance
```bash
./scripts/check.sh             # 12 steps (includes debug APK build)
./scripts/check.sh --quick     # 11 steps (skips build)
./scripts/check.sh --fix       # auto-format instead of read-only check
./scripts/check.sh --verbose   # stream command logs to terminal
```

| Step | What it enforces |
|------|-----------------|
| `flutter pub get` | Valid dependency resolution |
| `dart format` | Code formatting (`lib/`, `test/`, `scripts/`, `integration_test/`) |
| `flutter analyze` | Static analysis with hardened lint rules — **0 issues required** |
| `flutter test` | **295 tests** — 100% pass required |
| `flutter gen-l10n` | Localisation generation (35 locales) |
| Untranslated check | `.dart_tool/untranslated.json` — new keys tracked as non-blocking |
| **Privacy guard** | **Blocks** `firebase_analytics`, `google_analytics`, `appsflyer`, `amplitude`, `mixpanel`, `segment`, `sentry_flutter`, `facebook_app_events` |
| **Secret scan** | Flags hardcoded API keys (`sk-*`, `AIza*`) in `lib/` `test/` `scripts/` |
| **No-stale-name guard** | Blocks any `mq_navigation` references in `lib/`, `test/`, `scripts/`, `pubspec.yaml` |
| **No-login-route guard** | Blocks any `/auth/login`, `/auth/signup`, or `signInWithPassword` references |
| **No-Google guard** | Blocks any Google Maps SDK/files references in `lib/`, `android/`, `ios/`, `supabase/` |
| `flutter build apk --debug` | Android APK compiles (skipped with `--quick`) |

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## Documentation Map

| Document | Path |
|----------|------|
| Project Report (essay) | [`PROJECT_REPORT.md`](PROJECT_REPORT.md) |
| Architecture | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| Security Posture | [`docs/SECURITY_POSTURE.md`](docs/SECURITY_POSTURE.md) |
| Endpoint Inventory | [`docs/endpoint_inventory.md`](docs/endpoint_inventory.md) |
| Entity Inventory | [`docs/entity_inventory.md`](docs/entity_inventory.md) |
| Environment Variables | [`docs/env_inventory.md`](docs/env_inventory.md) |
| API Keys & Service Accounts | [`docs/key_inventory.md`](docs/key_inventory.md) |
| Map Inventory | [`docs/map_inventory.md`](docs/map_inventory.md) |
| Notification Matrix | [`docs/notification_matrix.md`](docs/notification_matrix.md) |
| Route Matrix | [`docs/route_matrix.md`](docs/route_matrix.md) |
| Contributing | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| Agent Rules & Changelog | [`AGENT.md`](AGENT.md) |

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## 🎯 Project Governance

### License
Released under the **MIT License**. See [`LICENSE`](LICENSE).

### Roadmap & Priorities
- **P0:** Open Day 2026 demo readiness (DONE).
- **P1:** Restore building image cache for offline mode.
- **P1:** Complete remaining 26 locales' translations.
- **P2:** Universal Links / App Links for first-class deep linking.
- **P2:** Voice-guided turn-by-turn for accessibility.

### Maintainers

| Name | Role |
|------|------|
| Pouya Alavi Naeini | Lead — architecture, mapping engine, infrastructure |
| Raouf Abedini | Co-maintainer — security, backend, Supabase Edge Functions |

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0067a5&height=2" width="100%"/>

<br/>

## Acknowledgements

Built with the support of the open-source community. This project benefits from:

- [Flutter](https://flutter.dev/) — Cross-platform UI toolkit.
- [Supabase](https://supabase.com/) — Open-source backend with Row-Level Security.
- [OpenStreetMap](https://www.openstreetmap.org/) — Map tile provider for the campus map renderer.
- [TfNSW Open Data](https://opendata.transport.nsw.gov.au/) — Live metro departures.

<br/>

<div align="center">

### `> ping --authors`

```text
> Authors    : Pouya Alavi Naeini — Software Engineer | Raouf Abedini — Back-End Developer
> University : Macquarie University, Sydney, NSW
> Product    : Macquarie University Open Day campus companion
> Submission : [●] READY — 295 tests passing · 0 analyzer issues
```

<br/>

</div>
