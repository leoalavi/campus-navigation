# Security Posture

Reviewed against the current client and Edge Function source on 4 November 2026. This is a design inventory, not a certification or a claim that every production control has been penetration tested.

## Privacy by Design
- **No account system**: The app starts directly at `/home` — no login, no signup, no email, no password.
- **No tracking**: No analytics, telemetry, or crash reporting packages (enforced by `check.sh` privacy guard).
- **Location**: The app does not maintain a location-history feature. Route and nearby-transport requests transmit coordinates to the relevant service and provider; see `docs/PRIVACY.md`.
- **Settings Privacy Badge**: Permanent "Private by design: no account, no tracking, no location history." card in Settings.
- **Safety Toolkit**: Emergency contacts use tap-to-dial (`url_launcher`) — location is never shared automatically.
- **Compass Mode**: All heading calculation is on-device via `FlutterCompass.events` — no data leaves the device.

## Authentication & Authorization
- **No login UI in the current router**: `/auth/login` and `/auth/signup` are not registered. Some legacy auth code remains in the repository, so "zero authentication code" would be inaccurate.
- **Public routing**: Production `maps-routes` version 21 has `verify_jwt=false` for signed-out callers. The function must validate requests and protect its server-side key without treating an anonymous caller as authenticated.
- **RLS**: Database access should be reviewed per table and function; an Edge Function's service-role access does not inherit caller RLS automatically.

## Data Security
- **At Rest**: The app uses `flutter_secure_storage` where secure local storage is needed. Public Supabase and platform Maps keys are build configuration, not secrets.
- **In Transit**: Network calls use HTTPS; this review did not independently establish a TLS 1.3-only policy for every endpoint.
- **Local Only**: User preferences, commute settings, and Open Day lead times are stored in `SharedPreferences` — never sent to a server.

## API & Edge Security
- **Proxy Pattern**: Server-side routing keys stay in Supabase Edge Function secrets. The mobile client does carry restricted, platform-specific Google Maps SDK keys needed to render map tiles.
- **Secret Scan**: Local `scripts/check.sh` scans source and scripts for selected hardcoded API-key patterns. `.github/workflows/ci.yml` does not currently run this script, so this is not a CI-enforced control.
- **Throttling**: A rate limiter exists in `maps-routes`, but the deployed function's client-IP header trust boundary has not been verified. Do not treat its per-IP limit as a proven security control; the proposed local revision was not deployed.
- **Input Validation**: Route inputs are validated by the Edge Function. Check current source before claiming that every mode is restricted to one campus bounding box.

## CI and local quality checks
- **Privacy Guard**: Local `check.sh` fails if listed analytics/tracking packages are added to `pubspec.yaml`; this guard is not in the current GitHub workflow.
- **Secret Scan**: grep-based detection of hardcoded API keys — excludes `supabase/` Edge Functions (which use `Deno.env.get()` for runtime env vars).
- **CI permissions**: `.github/workflows/ci.yml` grants `contents: read` and pins third-party actions to full commit SHAs. CI passed all six jobs on 4 November 2026 (run `41801652455`).

## 2026 Offensive Security Mitigation
- **Deep Links**: The app registers `mqnav://open`; `https://mqnavigation.app/open` still needs domain association files for verified App Links and Universal Links. It is not an `mq.edu.au` link.
- **Script Injection**: All HTML-rich routing instructions sanitized via `NavInstruction` normalization to prevent XSS.
- **Android Emulator Guard**: `LocationSource` rejects the default mocked Googleplex coordinate (`37.4219983, -122.084`) to prevent locate-me jumping to a US location on emulators.
