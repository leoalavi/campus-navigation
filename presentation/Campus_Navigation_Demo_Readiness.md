# Campus Navigation — Demo Readiness Report

Prepared: 18 November 2026, for the live demo at Macquarie University on 19 November 2026.

**Legend:** PASS = verified and working · FAIL = tested, not working ·
NOT TESTED = could not be verified here · NEEDS MANUAL CHECK = must be tested on campus

**Short answer:** Ready to demo **on the macOS laptop app, in debug mode**
(`./scripts/run.sh macos`). The map, search, building details, live routing
backend and live metro times all work. **Real GPS on campus has not been
tested** and needs the manual checks below.

---

## 1. Project status

| Item | Value |
|---|---|
| Branch | `main` (up to date with `origin/main`, last commit `9968691`) |
| Uncommitted work before this review | None. The working tree was clean. |
| Other branches | `stash/mqj-1`, `stash/mqj-2`, `stash/mqj-3`: untouched |
| Flutter / Dart | Flutter 3.44.0, Dart 3.12.0 (same as CI) |
| Key packages | flutter_riverpod 3, go_router 17, geolocator 14, google_maps_flutter (mobile), flutter_map + OpenStreetMap (desktop), supabase_flutter (routing and transit proxies), app_links (deep links) |
| Backend | Supabase Edge Functions: `maps-routes` (routes), `tfnsw-proxy` (metro times) |

Nothing has been committed or pushed.

---

## 2. Tests and builds

| Check | Result |
|---|---|
| `flutter pub get --enforce-lockfile` | PASS |
| `dart format --set-exit-if-changed` (all tracked Dart files) | PASS: 315 files, 0 changed |
| `dart analyze lib`, `test`, `tools` (as in CI) | PASS: no issues |
| `flutter test`: before changes | PASS: 765 / 765 |
| `flutter test`: after changes | PASS: **778 / 778** (13 new tests, incl. 10 for Preview Mode) |
| Coverage gate (≥ 50%, generated code excluded) | PASS: 60.31% |
| Secret scan (`lib`, `test`, `scripts`) | PASS: no keys in source. `.env`, `android/secrets.properties`, `ios/Flutter/Secrets.xcconfig` are gitignored. |
| `flutter build macos --debug` | PASS |
| `flutter build web --debug` | PASS (used only for a UI walkthrough) |
| `flutter build apk --debug` | FAIL (local environment). (1) Flutter uses Android Studio's JDK 25, which this Gradle can't parse. (2) With JDK 17, stale plugin outputs in `build/` cause "Zip file already contains entry". Likely fix: `flutter clean`. **Not run**, because it deletes all of `build/`, including an older `app-release.apk` from September. CI builds Android with JDK 17. |
| `flutter build ios --simulator --debug` | FAIL (toolchain). Under Xcode 27.2 Flutter rejects the simulator framework ("does not contain architectures arm64 x86_64"), but `lipo` shows that it does. CI pins Xcode 26.3. This is not a project bug, and iOS is not the demo platform. |
| Maestro E2E flows (`maestro/`) | NOT TESTED: needs a device or emulator and Maestro CLI |
| Integration tests | None exist in the repo (`integration_test/` is absent) |

---

## 3. Feature verification

How each item was checked: **unit/widget tests**, **live call** (real request
to the production backend), **web UI** (clicked through the web build in a
browser), or **macOS** (the real macOS app).

| Feature | Status | Evidence / notes |
|---|---|---|
| App start, onboarding, Home screen | PASS | macOS app launches. Web UI: onboarding → Skip → Home renders cleanly. |
| Campus map (bundled illustrated map) | PASS | Web UI. The map image is bundled, so it **needs no internet**. |
| Category buttons (Student Services, Faculty, Campus Hub, Food & Drink, Parking) | PASS | Visible in the web UI. Covered by widget tests. |
| Search | PASS | Web UI: "service connect" → 18WW, "library" → Waranara Library (7 results). |
| Building details panel | PASS | Web UI: name, code, category and description shown. |
| Route request → walking route | PASS (backend) / NEEDS MANUAL CHECK (with real GPS) | Live call: `maps-routes` returned a campus walking route (304 m, ~3.7 min) and a Google walking route (401 m, ~5.8 min) between two campus points. Not yet tested end to end with laptop GPS. |
| Travel modes (Walk / Drive / Bike / Transit) | PASS (UI) | Shown on the route panel. Campus Map renderer is walk-only by design. |
| Location permission / unavailable states | PASS (logic, web) | Tests cover the permission states. In the web UI an unsupported platform shows "Location is not available on this platform" and does not crash. |
| Real GPS on macOS (blue dot, locate button) | NEEDS MANUAL CHECK | macOS location is enabled in code and entitlements. Not tested with a real fix. A Mac laptop has no GPS chip, so position comes from Wi-Fi and may be 20–100 m off. |
| Live location updates while walking | NEEDS MANUAL CHECK | Covered by tests. See the known limitation on tracking below. |
| "Next Metro" live departures | PASS (backend) | Live call returned real M1 Metro departures (Bankstown / Tallawong). The Home card shows **"Not Set"** until a stop is chosen. |
| Deep link `mqnav://open?destination=18WW` (Syllabus Sync contract) | PASS on macOS (after fix) | `open "mqnav://open?destination=18WW"` reached the app (`going to /map/building/18WW`). On a fresh install onboarding takes over first, so finish onboarding before the demo. |
| End-to-end Syllabus Sync → Campus Navigation handoff | NOT TESTED | `docs/SYLLABUS_SYNC_INTEGRATION.md` calls the Syllabus Sync side an "integration intention" still to be checked in the other repo. |
| Google Maps tab on macOS | PASS (by design) | Desktop has no Google Maps SDK, so this tab shows **OpenStreetMap** tiles. It needs internet. Tiles are not cached on macOS (sandbox blocks the cache database). |
| Google Maps tab in **dark mode** (macOS, web) | PASS (after fix) | Used to show "API KEY REQUIRED" tiles: the dark map came from CARTO, which now needs a key. It now uses darkened OpenStreetMap tiles. Checked in the browser. |
| Preview Mode (1 Central Courtyard) | PASS (web, with real location unavailable) | Settings toggle shown with its explanation. Off: no dot and no banner. On: dot at 1 Central Courtyard, a readable "Preview location" banner, survives a reload, and Navigate with Google Maps drew a route from 1CC to Waranara Library (5 min, 330 m). Not run in the macOS app. |
| Directions in Chrome (web) | PASS with a stubbed position | Location used to be switched off on web. With browser location on, a route to Waranara Library drew correctly (5 min, 331 m) from the real backend. The position was stubbed in the test browser, so **real browser location is NEEDS MANUAL CHECK**. Chrome asks for permission on first use. |
| Real Google map + directions on web | **PASS** (stubbed position) | With a separate browser-only key (website restriction `http://localhost/*`, `http://127.0.0.1/*`; Maps JavaScript API enabled), the startup check reports `ready`. The Google Maps tab shows Google's map, and a walking route to Waranara Library draws on it (5 min, 331 m). The position was stubbed in the test browser, so **real browser location is NEEDS MANUAL CHECK**. If Google ever refuses the key, the tab falls back to the OpenStreetMap map (also checked). |
| Maps keys in `.env` | FIXED | `.env` had been replaced with another project's template. Its key names (`MAPS_API_KEY`, `…_ROUTES_KEY`) are not read by this app, and Google rejects those keys for this app's bundle ID and package. This app's original iOS and Android keys were appended under the right names. Only iOS and Android phones use them. |
| Open Day, QR stamps, 360° tours, Safety | NOT TESTED in depth | Covered by unit/widget tests only. Not part of the demo flow. |

---

## 4. Data accuracy

The app uses the bundled `assets/data/buildings.json` (161 entries). The
Supabase `building_registry` row is empty, so nothing remote overrides the
bundled file. This is good for reliability.

### Verified

| Item | Source | Result |
|---|---|---|
| 18 Wally's Walk = Service Connect (+ TechBar) | [students.mq.edu.au – 18WW](https://students.mq.edu.au/uni-life/campus/spaces/18WW) | Matches. Coordinates are **0 m** from OpenStreetMap's "18WW (Service Connect)". |
| Waranara Library, 16 Macquarie Walk | [MQ Library – contact us](https://www.mq.edu.au/about/facilities/library/about-us/contact-us) | Address matches. Coordinates 35 m from OSM. |
| Walanga Muru at 29 Wally's Walk | [MQ – Walanga Muru student engagement](https://www.mq.edu.au/about/about-the-university/indigenous-engagement-and-initiatives/engage-with-walanga-muru/student-engagement) | Matches (same coordinates as 29WW). |
| Open Day 2027 = Saturday 14 August 2027 | [event.mq.edu.au/open-day](https://event.mq.edu.au/open-day) | Matches the app's dataset. |
| Building coordinates vs OpenStreetMap | Nominatim (OSM) | Lotus Theatre 4 m · 4 Eastern Rd 5 m · 14 Sir Christopher Ondaatje Ave 21 m · Hospital 26 m · UBar 28 m · 17WW 35 m · 29WW 35 m · 1 Central Courtyard 63 m |
| Metro departures | Live TfNSW data via `tfnsw-proxy` | Working. Line name "M1 Metro North West & Bankstown Line" is current. |
| Data integrity | Script over `buildings.json` | No duplicate IDs. All 161 entries have coordinates. All coordinates fall inside the campus area. |

### Corrected

None. No confirmed errors were found in the demo buildings, and nothing was changed without a reliable source.

### Could not verify (flag, do not claim)

- **About 145 other entries** were not checked one by one.
- **Mia Mia (Childcare)** has the exact same coordinates as Walanga Muru and 29WW. This looks like a placeholder. **Do not use it in the demo.** It needs a check against the official campus map.
- **Macquarie Theatre (MQTH)** and **9 Wally's Walk (Engineering)**: OSM returned no reliable match, so they are unverified.
- **Wheelchair flags** (4 true, 157 false) are **not verified**. They are not shown in the UI, so **do not make accessibility claims**. The accessibility map overlay was not checked against the official accessibility map.
- **"Security & Emergency (24/7)"** hours were not re-checked.
- Four bike racks share duplicate display names (cosmetic).

---

## 5. Changes made

| File | Change | Why |
|---|---|---|
| `lib/features/map/presentation/controllers/map_controller.dart` | Startup waits at most **6 s** for the permission check and first GPS fix, then shows the map. A late fix is applied when it arrives. | Before, the whole map stayed on the loading spinner until GPS answered: up to ~15 s, or forever while the macOS permission prompt was open. That is the biggest risk for a live demo. |
| `test/features/map/map_controller_test.dart` | New test: the map opens while the permission prompt is still pending, then the late fix is applied. | Guards the fix above. |
| `lib/features/map/data/services/offline_maps_service.dart` | If the tile-cache database init **times out**, it is no longer marked "ready". | The old code marked it ready even after a timeout, so the map could get a broken tile provider. |
| `macos/Runner/Info.plist` | Registered the `mqnav` URL scheme. | iOS and Android already had it. Without it, macOS ignored `mqnav://open?destination=…` links. Verified working after the change. |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png` (7 sizes) | Replaced the old red arch icon with the current white-background icon (graduation cap and location pin), made from `assets/images/app_icon_tile.png` using the standard macOS layout (824 px tile on a 1024 px transparent canvas). | iOS, Android, web and the in-app startup screen already used this icon. macOS, the demo platform, still had the old one, because `flutter_launcher_icons` in `pubspec.yaml` has no `macos:` section. Checked in the built `.app`. |
| `lib/features/map/presentation/widgets/google/desktop_map_fallback_view.dart` | Dark mode uses OpenStreetMap tiles darkened with flutter_map's built-in `darkModeTileBuilder`, instead of CARTO `dark_all`. | CARTO's dark tiles now return an "API KEY REQUIRED" image, so the map was blank in dark mode on macOS and web. |
| `test/features/map/widgets/desktop_map_fallback_tiles_test.dart` | New: both themes must use keyless OSM tiles, and only dark mode darkens them. | Fails on the old code, passes on the fix. |
| `lib/features/map/data/datasources/location_source.dart` | Browser location turned on for web (via `geolocator_web`, already installed), with web-specific settings. Browsers have no settings page to open, so those buttons do nothing on web. | Directions could never work in Chrome: location was switched off on web, and every route needs a starting position. |
| `.env` (gitignored, not in the diff) | Appended `GOOGLE_MAPS_IOS_API_KEY` and `GOOGLE_MAPS_ANDROID_API_KEY` with this app's original keys (from the platform secret files). Your lines are unchanged. | The app reads only these names. Google rejects the keys you added for this app. |
| `web/flutter_bootstrap.js` (new), `web/index.html` | Load the Maps JavaScript API before the app starts, using the key in the gitignored `web/google_maps_config.js`, after a hidden test map confirms Google accepts it. Otherwise clear the key and use OpenStreetMap. | The Google Maps tab on web could never show Google's map: the loader was removed in `95d649c`. The test stops a refused key from showing Google's grey error box during the demo. |
| `lib/features/map/data/services/maps_key_resolver.dart`, `web_maps_key.dart`, `web_maps_key_stub.dart` | On web, the Google tab is used only when the test map passed (`window.CAMPUS_NAV_WEB_MAPS == 'ready'`). | It used to trust a compile-time define, which an IDE or `flutter run -d chrome` launch never passes, and which says nothing about whether Google accepted the key. |
| `.env`, `web/google_maps_config.js` (both gitignored) | `GOOGLE_MAPS_API_KEY` is now a **separate browser-only key** you created (the iOS and Android keys are unchanged and still accepted for their apps). The web config file was regenerated from it. | The web build reads the key from here. `scripts/run.sh` rewrites the web file from `.env` on each run. |
| `UserPreferences`, `settings_repository.dart`, `settings_controller.dart`, `settings_page.dart`, `app_en.arb` | New **Preview Mode** setting (off by default, saved on the device) with a toggle and a one-line explanation in Settings → Map. | Requested: a test fallback for when location services fail or are unavailable. |
| `map_controller.dart`, `route_leg.dart` (`LocationSample.isPreview`), `map_page.dart` | With Preview Mode on and **no real fix**, the map uses the 1 Central Courtyard entrance (from `buildings.json`) as the location: at startup, for the locate button and as the route origin. A real fix always replaces it. Turning the setting off removes it. A blue **"Preview location"** banner is shown whenever it's in use. | The preview origin is labelled so it is never presented as the user's real position. |
| Tests: `map_controller_test.dart` (+6), `settings_controller_test.dart` (+1), `settings_repository_test.dart` (+2), `settings_page_test.dart` (+1) | Cover default-off, start/locate/route from 1CC, real fix wins, error still shown when off, live toggle on and off, and saving. | |
| `presentation/*.md` | This report and the demo script. | Requested deliverables. |

Not changed: production data, Supabase, keys, CI, dependencies, iOS/Android config.
The macOS build also rewrote `macos/Runner.xcodeproj` (Flutter's automatic
Swift Package Manager migration). I reverted those generated changes. They
will reappear when you build, which is normal. Don't commit them by accident.

---

## 6. Known limitations

1. **Live dot may stop updating** after you select or close a building, until a route
   is loaded. The selection code stops location tracking on purpose. **Workaround:** press
   the locate button to refresh. Not changed: this is behaviour, not a crash, and changing it is riskier the night before.
2. **macOS location is Wi-Fi based**, not GPS. Indoors or on weak Wi-Fi it may be
   slow, off by tens of metres, or fail. The app then shows an honest error. It does not show a fake position.
3. **Routes need internet** (Supabase `maps-routes`). Without it you get "route unavailable" or network messages.
4. **OpenStreetMap tab needs internet** on macOS (no tile cache).
5. **No offline mode for routing or transit.** Only the campus map image and the building list work offline.
6. **Release mode will not start** with the current `.env`: `SUPABASE_URL` / `SUPABASE_ANON_KEY` are missing and release builds require them. **Use the default debug run.**
7. A deep link opened during first-run onboarding is dropped.
8. Cosmetic: the red category tag ("SERVICES") has low contrast in dark mode.

---

## 7. Demo instructions

### Recommended platform

**macOS laptop app, debug mode.** This is still the first choice: it uses the Mac's own location service and has no browser permission prompts.

**Backup, or to show Google Maps: Chrome.** The Google Maps tab shows Google's map, and directions draw on it. Run it with:

```bash
./scripts/run.sh chrome
```

`run.sh` copies the browser key from `.env` into `web/google_maps_config.js`. Chrome asks for location the first time, so click **Allow**. Use `localhost`, not a LAN IP address: the key only allows `localhost` and `127.0.0.1`.

### Launch command

```bash
cd ~/Documents/Projects/campus-navigation
```

```bash
./scripts/run.sh macos
```

Leave the terminal open. `r` = hot reload, `q` = quit. The first build takes a few minutes, so **build it tonight**.

### Before the audience arrives (10 minutes)

1. Connect to campus Wi-Fi (eduroam). Check that a web page loads.
2. **System Settings → Privacy & Security → Location Services**: turn on, and allow **Campus Navigation**.
3. Run the app. Finish or skip onboarding.
4. Open **Navigation**. Press the **locate button** (red, bottom right). Check that the blue dot is near you.
5. Do one full practice run: search → View in Campus Map → search again → Navigate with Google Maps → route line appears.
6. Optional: on the Home "Next Metro" card, tap the settings icon and choose **Macquarie University** station, so it shows live times instead of "Not Set".
7. Close any building panels and go back to **Home**.
8. Decide on **Preview Mode** (Settings → Map section). Leave it **off** if your real location works. Turn it **on** if location is unavailable or unreliable: the map then starts from 1 Central Courtyard and says so in a banner.

### Choosing a destination

You don't know exactly where you will stand. After the dot appears, pick a
destination **about 200–600 m away** that you can name confidently:

- **18 Wally's Walk (Service Connect)**: search `service connect`. Coordinates are exactly verified. *Default choice.*
- **Waranara Library**: search `library`. Use this if you are standing at 18WW.
- **Lotus Theatre**: search `lotus`. Use this if you are near the Library or the eastern side.

Avoid unverified entries (Mia Mia, Macquarie Theatre, 9WW).

### Demo sequence (2–3 min)

Home → Navigation (campus map) → locate button (real location) → search
"service connect" → View in Campus Map (details) → search again → Navigate
with Google Maps (walking route) → close → Home and wrap up.
The script with exact words is in `Campus_Navigation_Demo_Script.md`.

### Backup plan

| Problem | What to do |
|---|---|
| No blue dot after ~10 s | **Settings → Preview Mode → on**, then go back to Navigation. The dot moves to 1 Central Courtyard with a "Preview location" banner, and routes work from there. Say it's a preview starting point. (Or continue with search and details only.) |
| Route shows an error | Show the destination on the Campus Map (works offline). Explain that routes need internet and location. |
| No internet at all | Campus map, search and building details still work. Skip the route and "Next Metro". You could use a phone hotspot for the laptop. |
| App freezes or closes | In the terminal press `q`, run `./scripts/run.sh macos` again (~30–60 s once built). Keep talking meanwhile. |
| Everything fails | Show a **screen recording made tonight**, clearly said to be a recording. |

---

## 8. Manual checks on campus (before presenting)

- [ ] macOS asks for location permission and you can allow it
- [ ] Blue dot appears within ~10 s and is in roughly the right place
- [ ] Locate button moves the map to you
- [ ] Route from your real position to 18WW (or your chosen building) appears with distance and time
- [ ] Route line looks sensible (follows walkways, ends at the building)
- [ ] Walking a few metres updates the dot (after loading a route)
- [ ] Turning Wi-Fi off gives an error message, not a crash; turning it on again recovers
- [ ] "Next Metro" shows live times (if you set the stop)
