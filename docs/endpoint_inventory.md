# Endpoint Inventory — API Routes → Flutter Mapping

Reviewed 4 November 2026. This inventory includes code and historical web mappings; a listed endpoint is not proof that the current mobile UI exposes it.

Maps web API routes to their Flutter equivalents.

**Legend:**
- **SDK** = Call directly from Flutter via supabase_flutter (no server proxy needed)
- **EF** = Requires a Supabase Edge Function (server-side logic or secret keys)
- **N/A** = Not used by the Flutter app (web-only)

## Auth (legacy support code; no current login UI)

| Web Route | Method | Flutter Approach | Notes |
|-----------|--------|-----------------|-------|
| `/api/auth/signin` | POST | `supabase.auth.signInWithPassword()` in legacy repository code | `/auth/login` is not registered in the current Flutter router |
| `/api/auth/signup` | POST | `supabase.auth.signUp()` in legacy repository code | `/auth/signup` is not registered in the current Flutter router |
| `/api/auth/signout` | POST | `supabase.auth.signOut()` in legacy repository code | No current sign-out screen established by this inventory |

## Maps & Navigation (Used by Flutter)

| Web Route | Method | Flutter Approach | Notes |
|-----------|--------|-----------------|-------|
| `/api/maps/routes` | POST | **EF: `maps-routes`** | Flutter uses the Supabase Edge Function for both campus and Google routing |
| `/api/maps/place-search` | GET | **EF: `maps-places`** | Search suggestions with rate limiting |

> Flutter sends a normalized route request to `maps-routes` with
> `renderer`, `origin`, `destination`, and `travelMode`. The Edge Function
> dispatches to Google Routes for Google mode and to the campus walking backend
> for campus mode.

## Notifications (Used by Flutter)

| Web Route | Method | Flutter Approach | Notes |
|-----------|--------|-----------------|-------|
| `/api/notifications` | GET | SDK: `supabase.from('notifications')` | Inbox read/query |
| `/api/notifications` | POST | EF: `notify` | Stores inbox row + dispatches push |
| `/api/notifications/[id]` | GET/PUT/DELETE | SDK: direct table ops | |
| `/api/notifications/mark-all-read` | POST | SDK: `supabase.from('notifications').update({read: true})` | |

## Web-Only Endpoints (Not Used by Flutter)

The following endpoints exist in the web app but are not yet used by the Flutter app:

| Category | Web Routes | Reason Not Used |
|----------|-----------|-----------------|
| Content | `/api/units`, `/api/deadlines`, `/api/events`, `/api/todos` | Calendar/content features web-only |
| Profiles | `/api/profiles`, `/api/user-preferences` | Profile management web-only |
| Gamification | `/api/gamification/*` | Gamification not implemented |
| Weather | `/api/weather` | Not used by current map |
| Security | `/api/security/*`, `/api/audit` | Web-only security tools |
| Sync | `/api/sync` | Realtime not used in current scope |

## Edge Functions (in this repo)

| Edge Function | Purpose |
|---------------|---------|
| `maps-routes` | Shared campus/google route proxy with server-side Google/ORS keys |
| `maps-places` | Google Places autocomplete proxy with rate limiting and caching |
| `notify` | FCM push notification dispatcher |
| `cleanup-cron` | Rate-limit and cache record cleanup |

Web-only functions (`auth-email`, `auth-cleanup`, `routes-proxy`, `places-proxy`, `weather-proxy`, `security-utils`) were removed from this repo.
