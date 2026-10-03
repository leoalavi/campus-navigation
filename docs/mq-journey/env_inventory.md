# Environment Variable Inventory

All environment variables used by MQ Journey, categorised by client/server exposure.

## Client-Side (--dart-define in Flutter)

| Variable | Required | Default | Notes |
|----------|----------|---------|-------|
| `SUPABASE_URL` | Release only | Hardcoded dev fallback | Supabase project URL |
| `SUPABASE_ANON_KEY` | Release only | Hardcoded dev fallback | Public anon key (RLS enforced) |
| `APP_ENV` | No | `development` | development / staging / production |

> In **debug mode** a bare `flutter run` works for Supabase without
> `--dart-define-from-file=.env` because `env_config.dart` falls back to
> development defaults.
> In **release mode** you must supply at least `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

## Server-Only (Edge Functions env / Supabase dashboard)

| Variable | Service | Notes |
|----------|---------|-------|
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Functions | Bypasses RLS — never in client code |
| `ORS_API_KEY` | `maps-routes` EF | OpenRouteService key for campus routing |
| `TFNSW_API_KEY` | `maps-routes`, `tfnsw-proxy` EF | TfNSW Open Data API key (`Authorization: apikey <token>`) |
| `TFNSW_STOP_ID` | `tfnsw-proxy` EF | Optional station stop ID override (defaults to `10101403`) |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | `notify` EF | Firebase service account JSON for FCM HTTP v1 |
| `CRON_SECRET` | `cleanup-cron` EF | Protects cron endpoints |
| `ALLOWED_WEB_ORIGINS` | `maps-routes` EF | Optional comma-separated browser origin allowlist |

> **Note:** Route computation is server-side. All route secrets stay in Supabase
> Edge Function configuration — never exposed to the Flutter client.

## Firebase (Flutter-specific, not in web app)

| Variable | Location | Notes |
|----------|----------|-------|
| `google-services.json` | `android/app/` | Firebase Android config |
| `GoogleService-Info.plist` | `ios/Runner/` | Firebase iOS config |
| APNs auth key / certificate | Apple Developer + Firebase | Required for iOS push delivery |
