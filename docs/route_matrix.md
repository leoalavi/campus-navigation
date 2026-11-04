# Route Matrix — Flutter Routes

Checked against `lib/app/router/app_router.dart` and `route_names.dart` on 4 November 2026. Route registration does not by itself prove that external links work on a device.

| Flutter path | Route name | Purpose |
|---|---|---|
| `/open` | redirect | Deep-link contract; resolves a building, search query or coordinate to `/map` |
| `/meet` | `meet` | Redirects a shared coordinate to `/map` |
| `/home` | `home` | Home shell branch, index 0 |
| `/map` | `map` | Map shell branch, index 1 |
| `/map/building/:buildingId` | `building-detail` | Select a building; `?preview=route` starts a route preview |
| `/map/building/:buildingId/360` | `indoor-preview` | Building panorama; optional `?scene=` |
| `/scan` | `scan` | QR scanner shell branch, index 2 |
| `/settings` | `settings` | Settings shell branch, index 3 |
| `/notifications` | `notifications` | Notification inbox outside the shell |
| `/open-day` | `open-day` | Opt-in event screen outside the shell |
| `/your-day` | `your-day` | Event schedule outside the shell |
| `/onboarding` | `onboarding` | First-run setup |
| `/safety` | `safety` | Safety toolkit |
| `/favorites` | `favorites` | Saved buildings; standalone route, not a bottom tab |
| `/stamps` | `stamps` | Open Day passport |
| `/location/:locationId` | `location-detail` | Scanned location card |
| `/location/:locationId/ar` | `location-ar` | AR view for a scanned location |

The three visible bottom tabs are Home, Navigation and Settings. The scanner branch exists in the router and is presented when Open Day mode makes it available. The old `/auth/login` and `/auth/signup` routes are not registered in the current router.

`mqnav://open` is the custom-scheme handoff. `https://mqnavigation.app/open` needs the domain association files before it can work as an App Link or Universal Link. External deep-link behavior was not manually retested in the 4 November simulator review.
