# Route Matrix — Flutter Routes

All routes in the MQ Journey Flutter app.

## Page Routes

| Flutter Route | go_router Name | Description |
|---------------|----------------|-------------|
| `/home` | `home` | Welcome hub (shell tab 0) |
| `/map` | `map` | Campus map with illustrated renderer and search (shell tab 1) |
| `/map/building/:buildingId` | `building-detail` | Deep link to a specific building on the map |
| `/favorites` | `favorites` | List of favorited buildings (shell tab 2) |
| `/settings` | `settings` | Theme, language, preferences, data (shell tab 3) |
<!-- removed: /auth/login and /auth/signup -->
| `/safety` | `safety` | Safety toolkit (standalone page) |
| `/notifications` | `notifications` | Notification inbox (covers shell) |
| `/open-day` | `open-day` | Open Day event browsing and scheduling |
| `/onboarding` | `onboarding` | First-launch welcome and setup flow |
| `/meet` | `meet` | Map view focused on a shared point (lat/lng) |

## Shell Navigation (bottom nav)

| Tab | Index | Route | Icon |
|-----|-------|-------|------|
| Home | 0 | `/home` | home |
| Map | 1 | `/map` | map |
| Favorites | 2 | `/favorites` | favorite |
| Settings | 3 | `/settings` | settings |

## Shared Contract Routes

| Route Prefix | Feature | Contract Description |
|--------------|---------|----------------------|
| `/open/*` | Syllabus Sync | Deep link entry point for external unit schedules |
| `/map/meet/*` | Meet-at-Point | Temporary location sharing coordinate payload |

## Routes NOT Migrated from Web

| Web Route | Reason |
|-----------|--------|
| `/calendar` | Personal calendar features remain web-only for now |
| `/feed` | Event feed replaced by Home dashboard and Open Day module |
| `/manage-profiles` | Multi-profile management is a web-only admin feature |
| `/map/position-editor` | Admin-only building coordinate calibration tool |
| `/offline` | Flutter uses local-first caching and connectivity banners |
| `/api/*` | Handled via direct SDK calls or serverless Edge Functions |
