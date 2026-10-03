# Endpoint Inventory — API Routes → Flutter Mapping

Maps web API routes to their Flutter equivalents.

**Legend:**
- **SDK** = Call directly from Flutter via supabase_flutter (no server proxy needed)
- **EF** = Requires a Supabase Edge Function (server-side logic or secret keys)
- **N/A** = Not used by the Flutter app (web-only)

## Auth (Used by Flutter)

Auth is fully handled by Supabase anonymous sign-in on launch. No email/password flows exist in the Flutter app. See `auth_service.dart` and `auth_repository.dart` for the anonymous-only implementation.

## Maps & Navigation (Used by Flutter)

| Web Route | Method | Flutter Approach | Notes |
|-----------|--------|-----------------|-------|
| `/api/maps/routes` | POST | **EF: `maps-routes`** | Flutter uses the Supabase Edge Function for campus routing via ORS + TfNSW |

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
| `maps-routes` | Campus route proxy with server-side ORS + TfNSW keys |
| `tfnsw-proxy` | TfNSW Open Data transit timetable proxy |
| `notify` | FCM push notification dispatcher |
| `cleanup-cron` | Rate-limit, cache record, and orphaned anonymous user cleanup |

Web-only functions (`auth-email`, `auth-cleanup`, `routes-proxy`, `places-proxy`, `weather-proxy`, `security-utils`) were removed from this repo.
