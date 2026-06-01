<div align="center">

<!-- Typing animation -->
[![Typing SVG](https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=700&size=20&duration=2800&pause=700&color=A6192E&center=true&vCenter=true&width=860&lines=Mobile-first+campus+wayfinding+prototype;Flutter+%E2%80%A2+Dart+%E2%80%A2+Riverpod+%E2%80%A2+Supabase;Campus+locations+%E2%80%A2+Favourites+%E2%80%A2+Safety+support;Privacy-aware+design+%E2%80%A2+Testing+%E2%80%A2+Accessibility)](https://readme-typing-svg.demolab.com)

<!-- Badges -->
![License: MIT](https://img.shields.io/badge/License-MIT-f59e0b?style=for-the-badge)
![Flutter](https://img.shields.io/badge/Flutter_3.11+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart_3-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Riverpod](https://img.shields.io/badge/Riverpod_3.2-7C3AED?style=for-the-badge)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Google Maps](https://img.shields.io/badge/Google_Maps-4285F4?style=for-the-badge&logo=googlemaps&logoColor=white)
![Tests](https://img.shields.io/badge/323_Tests-Flutter_Test-6E9F18?style=for-the-badge)
![Material 3](https://img.shields.io/badge/Material_3-757575?style=for-the-badge&logo=materialdesign&logoColor=white)

</div>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

# MQ Navigation — Campus Wayfinding Prototype

> **Mobile-first campus wayfinding for Macquarie University students, visitors, and Open Day use cases.**

MQ Navigation is a mobile-first Flutter campus wayfinding prototype designed for Macquarie University students, visitors, prospective students, and Open Day attendees. It helps users find buildings, services, transport, food, parking, and key campus locations through a focused mobile interface. The app features dual-renderer maps, routing via a Supabase Edge proxy, compass mode, a campus safety toolkit, transit countdowns, and multi-language i18n — built with a privacy-aware approach: optional account, zero analytics packages, and no location history stored.

MQ Navigation was developed as a companion project to [Syllabus Sync](https://github.com/mrpouyaalavi/syllabus-sync), the broader student experience platform, sharing a Supabase backend in a **two frontends, one backend** architecture. Submitted for **COMP3130 Mobile App Development — Major Project (May 2026)**.

**[📖 Project Report](PROJECT_REPORT.md)** &nbsp;·&nbsp; **[📸 Screenshots](screenshots/)** &nbsp;·&nbsp; **[🏗️ Architecture](docs/ARCHITECTURE.md)** &nbsp;·&nbsp; **[🔐 Security Posture](docs/SECURITY_POSTURE.md)**

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

## 📌 For Markers / Reviewers — Quick Start

| Step | Action |
|------|--------|
| 1 | `flutter pub get && flutter gen-l10n` |
| 2 | Copy `.env.example` → `.env`. The repo ships with a working Supabase test project anon key — no setup needed for graders. |
| 3 | `flutter run --dart-define-from-file=.env` (Android emulator or Chrome) |
| 4 | Sign in with the demo credentials below, or tap **Create one** to register a fresh account. |
| 5 | Tap a building → ❤️ to favourite. Visit the **Favourites** tab to Edit (note) and Delete (kebab menu). |

### Demo / Test Credentials

```
Email:    marker@mq-navigation.test
Password: OpenDay2026!
```

> These are demo-only credentials for a test Supabase project. They are not connected to any real Macquarie University system. A fresh account can also be created from the Sign Up screen — email confirmation is disabled on the test project so registration is instant.

### Where to find each rubric requirement

| Requirement | Where it lives |
|-------------|---------------|
| **User authentication** | `lib/features/auth/` — Supabase Auth (login, signup, logout, error mapping, silent existing-user detection) |
| **Remote database (Supabase)** | `favorite_buildings`, `notifications`, `notification_preferences` tables; `lib/features/favorites/data/` and `lib/features/notifications/data/` |
| **CRUD on a data entity** | Favourites: **Create** via ❤️ on any building, **Read** on the Favourites tab, **Update** via the kebab → Edit note, **Delete** via swipe or kebab → Remove |
| **Mobile device service** | `geolocator` (GPS), `flutter_compass` (heading), `torch_light` (flashlight) — all in `lib/features/map/` and `lib/features/safety/` |
| **Widget tests** | `test/features/*/` — 50+ widget tests, including 10 for the Favourites page with full interaction coverage |
| **Unit tests** | 240+ unit tests across map, auth, favourites, notifications, settings, transit, open day |
| **Project Report / Essay** | [`PROJECT_REPORT.md`](PROJECT_REPORT.md) — 820-word essay addressing the required questions (app description, core features, audience personas, competitor advantages, technical credentials, and layout) |

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

## 🎯 Problem & Value Proposition

Generic campus maps (Google/Apple Maps) stop at the street kerb and don't know which door is *18 Wally's Walk*. Existing university portals often require sign-on and offer a poor mobile experience. MQ Navigation addresses this by providing:

- **Mobile-first campus wayfinding** — Building and key location discovery optimised for phone-sized screens.
- **Building and location discovery** — 161+ named campus buildings, services, and points of interest pinpointed at the correct entrance.
- **Favourites and saved places** — Heart-toggle, edit-note, and swipe-to-delete for personalised place saving (cloud-synced when signed in).
- **Safety and support information** — One-tap access to emergency contacts, AEDs, first aid, campus shuttle, and torch.
- **Routing and transit** — Server-side walking/driving/cycling/transit routing via Supabase Edge proxy; live metro countdown on the home screen.
- **Privacy-aware design** — Optional account, no analytics SDKs, GPS used ephemerally and never persisted.

<br/>

## Why This Project Matters

This project explores how a campus navigation experience can be more focused, privacy-aware, and student-centred than a generic map interface. Three design goals shaped its architecture:

1. **Privacy-aware by design.** Real GPS, real routing, real building markers, real safety contacts — and zero analytics SDKs. The CI privacy guard refuses to compile the app if any tracking package is added to `pubspec.yaml`.
2. **Localisation as a first-class concern.** 35 ARB locales with RTL layout support for Arabic, Farsi, Hebrew, and Urdu — not just `flutter gen-l10n` output.
3. **Two frontends, one backend.** The same Supabase project powers this Flutter client and the Syllabus Sync Next.js platform — sharing data models, auth users, and Edge Functions without forcing a single UI.

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

## Screenshots

<div align="center">

| Login | Home |
|:---:|:---:|
| <img width="320" alt="Login" src="screenshots/01_login_page.png"/> | <img width="320" alt="Home" src="screenshots/02_home_page.png"/> |

| Map | Safety |
|:---:|:---:|
| <img width="320" alt="Map" src="screenshots/03_map_page.png"/> | <img width="320" alt="Safety" src="screenshots/04_safety_page.png"/> |

| Favourites | Notifications | Settings |
|:---:|:---:|:---:|
| <img width="240" alt="Favourites" src="screenshots/05_favorites_page.png"/> | <img width="240" alt="Notifications" src="screenshots/06_notifications_page.png"/> | <img width="240" alt="Settings" src="screenshots/07_settings_page.png"/> |

</div>

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

## Key Features

```text
╔══════════════════════════════════════════════════════════════════════╗
║  🗺  Dual-renderer maps: Google Maps + calibrated illustrated campus ║
║  🧭  On-device compass mode with bearing-to-destination arrow        ║
║  🛣  Routing via Supabase Edge proxy → Google Routes V2 API          ║
║  ❤️  Favourites CRUD: heart-toggle, edit-note, swipe-to-delete       ║
║  🚨  Campus Safety Toolkit: 000, AEDs, first aid, shuttle, torch     ║
║  🚆  Macquarie Uni metro countdown via TfNSW Open Data proxy         ║
║  🌍  35 locales · RTL layout support for ar/fa/he/ur                 ║
║  🔐  Optional auth · Zero analytics · CI-enforced privacy guard      ║
║  ⚡  323 tests · 0 analyzer issues · 8-step quality gate script       ║
╚══════════════════════════════════════════════════════════════════════╝
```

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

## 🏗️ Technical Architecture Overview

MQ Navigation is built on a modern Flutter stack designed for mobile usability, type safety, privacy-aware data handling, and maintainable feature modules.

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
        F --> G[Google Routes V2]
        F --> H[Google Places]
        F --> I[TfNSW Open Data]
    end
```

### Runtime Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter 3.11+ (Stable channel) |
| **State** | Riverpod 3.2 (AsyncNotifier) |
| **Routing** | GoRouter 17.1 (StatefulShellRoute, 4 tabs + standalone routes) |
| **Maps** | google_maps_flutter 2.15 / flutter_map 8.2 |
| **Backend** | Supabase (Postgres, RLS, Realtime, Deno Edge Functions) |
| **Location** | geolocator 14 (raw GPS + last-known fallback, emulator mock rejection) |
| **Compass** | flutter_compass 0.8 |
| **Notifications** | Firebase Messaging + flutter_local_notifications 21 |
| **i18n** | flutter_localizations + intl — 35 ARB locales, RTL for ar/fa/he/ur |
| **Security** | flutter_secure_storage 10 (iOS Keychain / Android Keystore) |

### Key Architectural Decisions

- **Defensive bootstrap with timeouts:** `Firebase.initializeApp()` and `Supabase.initialize()` are both wrapped in `.timeout()` calls so the app cannot hang on a stalled network during cold start (root cause we hit during Release-mode testing).
- **Silent existing-user detection:** `AuthRepository.signUp` inspects `response.user.identities` to detect when Supabase silently returns an existing-confirmed account and shows a real error instead of a misleading "Account created" banner.
- **Renderer-aware Building actions:** `BuildingActionsSheet` distinguishes "View in Campus Map" (marker only) from "Navigate with Google Maps" (route preview auto-loaded) via a `?preview=route` query parameter.
- **CI privacy guard:** `scripts/check.sh` refuses to compile if any analytics package (`firebase_analytics`, `google_analytics`, `appsflyer`, `amplitude`, `mixpanel`, `segment`, `sentry_flutter`, `facebook_app_events`) is added to `pubspec.yaml`.

> **Deep Dive:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · [`docs/SECURITY_POSTURE.md`](docs/SECURITY_POSTURE.md) · [`docs/route_matrix.md`](docs/route_matrix.md)

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

## 🔒 Privacy-Aware Design

Privacy is treated as an architectural concern, not a feature flag. The following principles guided design decisions across the codebase.

| Principle | Implementation |
|-----------|---------------|
| Optional account | Auth is **fully optional** — the app works at `/home` without login. Account only needed for cloud-synced favourites. |
| No analytics packages | No analytics, telemetry, or crash reporting packages included. CI guard blocks them at PR time. |
| Ephemeral location use | GPS used for active navigation only — not persisted, not transmitted to any external service. |
| Local-only preferences | Theme, locale, commute mode, and quiet hours stored via `SharedPreferences` + `FlutterSecureStorage`. |
| Safety privacy | Emergency contacts use tap-to-dial — location is **never automatically shared**. |
| On-device compass | All heading calculation happens on-device. No data leaves the phone. |

> **Defence-in-depth model:** [`docs/SECURITY_POSTURE.md`](docs/SECURITY_POSTURE.md) · [`docs/key_inventory.md`](docs/key_inventory.md)

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

## Who is this for?

MQ Navigation was designed around four user personas — representing different ways a person might interact with a campus wayfinding app.

| Persona | Goals | Relevant capability |
|---------|-------|---------------------|
| **"Open Day Olivia"** — Year 12 prospective student visiting campus for the first time. | Find the Faculty of Arts building, the Library, and where her parents parked. | Built-for-Macquarie illustrated campus map with 161+ named buildings — Google Maps shows roads, not which door is *18 Wally's Walk*. |
| **"Commuter Chen"** — First-year domestic student catching the Metro. | Know if he's late for his 9am tutorial. Find the nearest defibrillator if needed. | Live Macquarie Uni metro countdown on the home screen + Safety Toolkit one tap away. |
| **"International Isha"** — New PhD student navigating campus in her second language. | Read the app in her preferred language. Save rooms her supervisor mentioned. | 35-language i18n with RTL layout support for Arabic, Farsi, Hebrew, and Urdu. |
| **"Accessibility Alex"** — Low-vision student who uses a screen reader. | High-contrast map mode, no flashing animations, predictable navigation. | Reduced-motion toggle, high-contrast map mode, semantic widgets, no tracking SDKs. |

**Why a dedicated campus app over Google/Apple Maps?** Generic maps stop at the street. MQ Navigation starts at the building entrance — with a privacy-aware approach and campus-specific data baked in.

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

## Device Compatibility

| Platform | Status | Notes |
|----------|--------|-------|
| **Android emulator** (API 33+) | ✅ Verified | All features verified. Recommended for marking. |
| **Android physical device** | ✅ Verified | Compass, flashlight, GPS, push notifications all functional. |
| **Chrome (web)** | ✅ Core features | Auth, favourites CRUD, maps, routing, transit countdown work. Compass mode and flashlight gracefully degrade — UI displays an "unsupported on this device" fallback. |
| **iOS device** | ⚠️ Expected / Not fully verified | Native build configured for iPhone (iOS 17+). Custom URL scheme `io.mqnavigation://` registered for auth callbacks. Full device testing not guaranteed. |
| **macOS desktop** | ⚠️ Expected / Not fully verified | Location, auth, and dual-renderer configured. CFBundleURLTypes registered so auth deep links return to the app. Google Maps falls back to OSM (plugin limitation). Full device testing not guaranteed. |

If a platform-specific issue surfaces during review, the relevant feature renders a typed `MapStateError` fallback rather than crashing.

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

## Repository Layout

```text
lib/
├── app/              Bootstrap, router, theme, l10n (35 ARB locales)
├── core/             Config, error handling, logging, networking, security
├── shared/           Extensions, models, widgets (MqButton, MqCard, MqInput)
└── features/
    ├── auth/         Supabase Auth (login, signup, session persistence, gate)
    ├── favorites/    Building favourites CRUD (controller, repo, datasource, UI)
    ├── home/         Welcome dashboard, onboarding, metro countdown
    ├── map/          Dual-renderer, routing, compass mode, search, favourites
    ├── safety/       Safety toolkit, emergency contacts, first aid / AED
    ├── notifications/ FCM push, local reminders, inbox
    ├── open_day/     Open Day events, study interest, reminders
    ├── settings/     Preferences, privacy badge, data wipe, account management
    ├── transit/      Metro/bus/train search, commute prefs
    ├── timetable/    Unit and class schedule management
    └── deep_link/    Syllabus Sync deep link contract

test/                 323 widget & unit tests (flutter_test suite)
supabase/             Edge Functions (maps-routes, tfnsw-proxy)
docs/                 9 reference documents (architecture, security, inventories)
screenshots/          7 screen captures used in this README
scripts/              run.sh, check.sh (quality gate)
```

> **Full Inventory:** [`docs/map_inventory.md`](docs/map_inventory.md) · [`docs/endpoint_inventory.md`](docs/endpoint_inventory.md) · [`docs/entity_inventory.md`](docs/entity_inventory.md)

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

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
cd mq_navigation
flutter pub get

# Configure environment
cp .env.example .env
# Edit .env with your Supabase + Google Maps credentials
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
./scripts/check.sh             # 9 steps (includes debug APK build)
./scripts/check.sh --quick     # 8 steps (skips build)
./scripts/check.sh --fix       # auto-format instead of read-only check
./scripts/check.sh --verbose   # stream command logs to terminal
```

| Step | What it enforces |
|------|-----------------|
| `flutter pub get` | Valid dependency resolution |
| `dart format` | Code formatting (`lib/`, `test/`, `scripts/`, `integration_test/`) |
| `flutter analyze` | Static analysis with hardened lint rules — **0 issues required** |
| `flutter test` | **323 tests** — 100% pass required |
| `flutter gen-l10n` | Localisation generation (35 locales) |
| Untranslated check | `.dart_tool/untranslated.json` — new keys tracked as non-blocking |
| **Privacy guard** | **Blocks** `firebase_analytics`, `google_analytics`, `appsflyer`, `amplitude`, `mixpanel`, `segment`, `sentry_flutter`, `facebook_app_events` |
| **Secret scan** | Flags hardcoded API keys (`sk-*`, `AIza*`) in `lib/` `test/` `scripts/` |
| `flutter build apk --debug` | Android APK compiles (skipped with `--quick`) |

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

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

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

## 🎯 Project Governance

### License
Released under the **MIT License**. See [`LICENSE`](LICENSE).

### Roadmap & Priorities
- **P0:** Open Day-style demo readiness.
- **P1:** Hosted HTTPS callback page so the email-confirmation flow works on desktop browsers without the app installed.
- **P1:** Translator passes on the remaining 26 locales' auth strings.
- **P2:** Universal Links / App Links for first-class deep linking.
- **P2:** Voice-guided turn-by-turn for accessibility.

### Maintainers

| Name | Role |
|------|------|
| Pouya Alavi Naeini | Lead — architecture, mapping engine, infrastructure |
| Raouf Abedini | Co-maintainer — security, backend, Supabase Edge Functions |

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:0f172a,30:a6192e,60:fbbf24,100:0f172a&height=2" width="100%"/>

<br/>

## Acknowledgements

Built with the support of the open-source community. This project benefits from:

- [Flutter](https://flutter.dev/) — Cross-platform UI toolkit.
- [Supabase](https://supabase.com/) — Open-source backend with Row-Level Security.
- [OpenStreetMap](https://www.openstreetmap.org/) — Map tile provider for the Campus Map fallback renderer.
- [TfNSW Open Data](https://opendata.transport.nsw.gov.au/) — Live metro departures.

<br/>

<div align="center">

### `> ping --authors`

```text
> Authors    : Pouya Alavi Naeini — Software Engineer | Raouf Abedini — Back-End Developer
> University : Macquarie University, Sydney, NSW
> Unit       : COMP3130 Mobile App Development — Major Project (50%)
> Submission : [●] READY — 323 tests passing · 0 analyzer issues
```

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-a6192e?style=for-the-badge&logo=linkedin&logoColor=ffffff&labelColor=0f172a)](https://www.linkedin.com/in/pouya-alavi/)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-fbbf24?style=for-the-badge&logo=github&logoColor=ffffff&labelColor=0f172a)](https://github.com/mrpouyaalavi)
[![Email](https://img.shields.io/badge/Email-Contact-f59e0b?style=for-the-badge&logo=gmail&logoColor=09090b&labelColor=0f172a)](mailto:pouya@pouyaalavi.dev)

<br/>

*MQ Navigation is an independent open-source student project and is not officially affiliated with Macquarie University.*

</div>
