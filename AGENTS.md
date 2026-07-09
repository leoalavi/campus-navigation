# AGENTS.md — MQ Journey

Working memory for Codex on the **MQ Journey** Flutter app (Macquarie University campus navigation; formerly "MQ Navigation"). For the full, append-only project history see `AGENT.md` + `CHANGELOG.md`; this file is the fast, actionable summary.

---

## 1. What this is

- **Package:** `mq_journey` (pubspec `name: mq_journey`, bundle/scheme `io.mqjourney` with legacy alias `io.mqnavigation`).
- **Stack:** Flutter (Dart SDK `^3.11.0`, Flutter 3.41.x) → Supabase backend (Postgres + RLS + Edge Functions + Realtime). Firebase only for messaging.
- **Frontends:** This Flutter app + a separate Next.js web app share the **same Supabase backend**. Never fork the backend.
- **No login:** App boots straight to `/home` (or `/onboarding`) on a **silent anonymous** Supabase session (`signInAnonymously()`). There is no email/password UI. Writes go through the injectable `sessionGuardProvider` (retry-on-write). Do not reintroduce a login/signup route — CI guards against it.

## 2. Commands

```bash
flutter pub get                 # deps
flutter analyze                 # static analysis (CI runs --no-fatal-infos)
flutter test                    # full suite (~365 tests)
flutter test path/to/file.dart  # single file
flutter gen-l10n                # regenerate localisations after editing ARB files
flutter run -d macos            # run desktop (Firebase/Supabase/ObjectBox not configured on macOS — runtime warnings are expected)
scripts/check.sh                # full CI gate (see §6); --quick skips the APK build, --fix auto-formats
```

Use `! <cmd>` in the prompt for interactive commands (e.g. `gcloud auth login`).

## 3. Architecture

- **Feature-first** with `data / domain / presentation` layers per feature under `lib/features/<name>/`.
- **State:** Riverpod (`flutter_riverpod ^3.2.1`). Providers live in `lib/features/<name>/providers/` or alongside adapters.
- **Routing:** `go_router ^17` with a `StatefulShellRoute` for the 4-tab bottom nav (Home, Journey, Scan, Settings; indices centralized in `ShellBranchIndex`). Route names in `lib/app/router/route_names.dart`.
- **Theme:** MQ design tokens — `MqColors`, `MqTypography`, `MqSpacing` (`lib/app/theme/`). Use these, not raw colors/sizes.
- **i18n:** ARB files in `lib/app/l10n/`, **35 locales**, RTL for ar/fa/he/ur. Add keys to `app_en.arb`; untranslated keys in other locales are tolerated by CI but should be synced.
- **Boundaries:** Flutter is presentation-only. No server logic or secrets in the app binary — API keys live in Edge Functions; config comes via `--dart-define`.

Key dirs: `lib/app/` (bootstrap, router, theme, l10n), `lib/core/` (config, error, logging, network, security, utils), `lib/shared/` (MQ widgets/models/extensions), `lib/features/` (home, map, scan, settings, favorites, notifications, open_day, auth).

## 4. Conventions

- Match surrounding code style; respect `analysis_options.yaml` (flutter_lints). CI runs `dart format --set-exit-if-changed` — **always format before claiming done**.
- Tests use `flutter_test` + `mocktail`. Mirror `lib/` paths under `test/`.
- Riverpod `ref.watch` may be called conditionally / after early returns in `build` (unlike React hooks) — that's fine here.
- Prefer the injected provider seams for testability (e.g. `sessionGuardProvider`, `progressApiProvider`, fakes under `domain/fakes/`).

## 5. Feature gotchas (hard-won)

**Assets are NON-recursive.** A `pubspec.yaml` entry like `assets/data/` bundles only files *directly* in that dir — **not** subdirectories. Every asset subfolder needs its own line (e.g. `assets/data/indoor/`, `assets/web/pannellum/`). Asset keys are **case-sensitive** (`C3A.json` ≠ `c3a.json`) — don't lowercase building codes when building asset paths. Verify with the bundled `AssetManifest.bin` after a build, not just by eyeballing pubspec.

**Scan feature (`lib/features/scan/`)** — QR scan → location card → indoor 360° preview → visit tracking:
- Camera via `mobile_scanner ^7.2.0`. v7 lifecycle: own the `MobileScannerController`, guard `pause()/start()` with `controller.value.hasCameraPermission`, reflect torch state from `controller.value.torchState` (don't track a local bool — `toggleTorch()` no-ops if the camera isn't running). `errorBuilder`/`placeholderBuilder` are 2-param in v7.
- Indoor preview uses `flutter_inappwebview ^6.1.5` + Pannellum (vendored in `assets/web/pannellum/`). Load assets via an `InAppLocalhostServer(documentRoot: 'assets')` over `http://localhost:8459`, **not** `file://`/`initialFile` — file URLs can't resolve cross-directory panorama refs.
- **Indoor manifest schema:** the JSON assets (`assets/data/indoor/*.json`) use neighbour keys `targetId`/`heading`; the parser also accepts legacy `id`/`bearing`. Panorama `image` values already include the `indoor/` segment, so `buildPannellumConfig(assetBaseUrl: '<base>/data')`.
- **Visits** are tracked by **building code** (not locationId): `VisitEvent.buildingId` → `recordLocationVisit(buildingCode)` → `visitedLocationCodes`. The visited badge must watch `visitedStateProvider(content.buildingId ?? locationId)`. Remote `open_day_stamps` upsert is keyed by `location_id` (different system — that's intentional).
- ⚠️ Panorama **image files don't exist yet** (`assets/data/indoor/c3a_*.jpg`, `18ww_*.jpg` are referenced but missing) — the viewer renders black until they're supplied.

**Map + AR (`lib/features/map/`):** `MapModeToggle` (Campus Map ↔ AR) drives `MapShell.mapMode`; AR mode renders `ArBuildingPicker` (or the selected building's `IndoorPreviewPage`). The picker auto-selects when exactly one building has a manifest and locks ("coming soon") the rest.

## 6. CI gate (`scripts/check.sh`)

Steps: pub get → format check → `flutter analyze --no-fatal-infos` → `flutter test` → `gen-l10n` → untranslated-l10n check → **privacy guard** (no tracking/analytics packages) → **secret scan** (no hardcoded keys) → **no-stale-name guard** (no `mq_navigation`) → **no-login-route guard** → **no-Google guard** (no Google Maps) → (full run only) `flutter build apk --debug`.

Known pre-existing non-blockers: the no-Google guard false-positive and a Gradle/Kotlin build-env issue. `info`-level lints (e.g. `prefer_const_constructors` in some test files) don't fail analyze.

## 7. Workflow rules (Raouf change protocol)

1. **Before changing code:** read `AGENT.md` + changelogs (`CHANGELOG.md`).
2. **After changing code:** add a `### Raouf: <YYYY-MM-DD> (Australia/Sydney) — <title>` entry to **both** `AGENT.md` and `CHANGELOG.md` (newest-first, at the top), with **Scope / Summary / Files Changed / Verification / Follow-ups**.
3. When blocked or touching a library, fetch the **latest official docs** (Context7 MCP — mobile_scanner, flutter_inappwebview, riverpod, go_router, supabase, etc.) before guessing.
4. Don't commit/push unless asked. If on `main`, branch first. Co-author trailer: `Co-Authored-By: Codex Opus 4.8 <noreply@anthropic.com>`.

## 8. Don't

- Don't reintroduce auth/login routes, Google Maps, analytics/tracking SDKs, or the `mq_navigation` name (all CI-guarded).
- Don't put secrets in the app or in version control.
- Don't lowercase asset paths or assume nested asset dirs are auto-bundled.
- Don't claim "done"/"passing" without running `flutter analyze` + `flutter test` and citing the result.
