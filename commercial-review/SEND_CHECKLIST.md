# Send package: final checklist

## A. Email subject
**Campus Navigation app: project summary and request for guidance on use of the University campus map**

## B. Final recommended email body
Use **"Recommended final version"** in `FINAL_EMAIL.md`. Before sending, resolve every ⟦…⟧: confirm it with evidence, or delete the sentence.

## C. Attachments to send
1. `screenshots/01_campus-map_live-location.png`
2. `screenshots/03_search_location-discovery.png`
3. `screenshots/04_360-panorama_macquarie-theatre.png`
4. `screenshots/05_about_independence-notice.png`
5. `screenshots/07_disclosure_bundled-university-map-with-crest.png`
6. *(optional)* `screenshots/06_optional_open-day-qr-location-card.png`
7. *(recommended once captured)* `screenshots/02_walking-route.png`

Optionally paste `PROJECT_SUMMARY.md` into the email body, or attach it as a one-page PDF. Total attachment size is ≈9 MB. If your mail client struggles, the 360° image (4.6 MB) can be converted to JPEG.

## D. Screenshot filenames
| # | File | Status |
|---|---|---|
| 01 | `01_campus-map_live-location.png` | ✅ captured |
| 02 | `02_walking-route.png` | ❌ **not captured** (see I-1) |
| 03 | `03_search_location-discovery.png` | ✅ captured |
| 04 | `04_360-panorama_macquarie-theatre.png` | ✅ captured |
| 05 | `05_about_independence-notice.png` | ✅ captured |
| 06 | `06_optional_open-day-qr-location-card.png` | ✅ captured (optional) |
| 07 | `07_disclosure_bundled-university-map-with-crest.png` | ✅ crop of the bundled asset (not an app screen) |

All captured on an iPhone 17 Pro simulator (iOS 26.5) at 1206×2622, with a clean status bar (09:41, full battery). The location was simulated at the 18 Wally's Walk entrance, which is not a personal location. No accounts, email addresses or debug UI are visible, except the public support address `leo@leoalavi.dev` on the About screen. Screenshots were not cropped further: they are full-screen phone captures, which reads naturally as "this is the app".

## E. Screenshot captions
- **01:** The University's published campus map inside the app, with the user's live location placed on it by our GPS calibration.
- **02:** A walking route drawn on the map with step-by-step instructions. Route paths come from Google / OpenRouteService; the display and instructions are ours.
- **03:** Searching "theatre" across our database of 161 campus locations, by name or building code.
- **04:** One of our 360° panoramic photos (Macquarie Theatre entrance), with a hotspot to move into the foyer.
- **05:** The About screen, naming the developers and stating the app is not affiliated with, endorsed by, or published by any university.
- **06:** Optional Open Day mode: a signed QR code opens a building card with photo, description and map link.
- **07:** The University's published campus map exactly as bundled in the app, including the crest and wordmark we are asking about.

## F. Evidence to keep but not send
- `PROJECT_TIMELINE.md`, `IP_AND_ASSET_BOUNDARY.md` (send if asked), `CLAIM_VERIFICATION.md`, `RISK_CHECKLIST.md`, `SUPPORTING_EVIDENCE.md`, `../MQ_Commercial_Review_Brief.md`
- Git history (notably `2ac9b41` "Final commit for assignment", 2026-05-24; merge `43c8b24`)
- QR posters and the contact sheet; QA reports (marked "pending")
- `docs/ARCHITECTURE.md`, `docs/PRIVACY.md`, `docs/SECURITY_POSTURE.md`, `LICENSE`
- The Astronomy App Store listing URL: apps.apple.com/au/app/astronomy-open-night-2026/id6808865067
- Everything in `SUPPORTING_EVIDENCE.md` §B, once collected
- **Do not send:** `PROJECT_REPORT.md` (credentials), old `screenshots/`, `docs/mq-journey/`, `AGENT.md`, `CHANGELOG.md`, the store listing drafts, or the current `README.md`

## G. Claims to avoid
- That the map, the overlays or "the maps" are our own work, or "transformed"
- "Official", "endorsed", "approved", "partnered with Macquarie", "for Macquarie University" (as if commissioned)
- That the copyright representative approved the app (she said the concept seemed acceptable from a copyright perspective and referred you on)
- "3D photos". Say "360° panoramic photos"
- Our own routing engine or campus path network
- Every location pinpointed at its entrance (6 of 161 have entrance coordinates)
- Step-free or accessible routing
- "Location never leaves your device"
- Used at Open Day 2026 (no evidence)
- Used at Astronomy Open Night, unless you hold the evidence
- Incubator participation or investor talks, unless you hold the evidence; never that the University arranged investment
- Download or user numbers; "published" for Campus Navigation (it isn't)
- That Syllabus Sync is a company, or owns the app
- That Campus Navigation "grew out of" the Open Day app (it is the reverse)
- That the University's own web map is slow, requires SSO, or lacks routing

## H. Questions to ask if they reply
See `QUESTIONS_FOR_MACQUARIE.md`. The six in the email are ★ items 1/2, 5, 13/14, 19 and 25. Hold the rest for a meeting, especially:
- data sources and APIs (9–12);
- review of updates (16);
- making the public repos private (18);
- the coursework boundary (20–21);
- the commercial pathway and Incubator channel (23–24);
- the timeframe (26).

## I. Facts you must personally verify before sending
1. **Walking-route screenshot (02) could not be captured.** In this local build:
   - The UI starts routes only from "Navigate with Google Maps". With no Google Maps API key configured locally (there is no `.env`), opening the Google renderer **crashed the app**: `GMSServicesException: Google Maps SDK for iOS must be initialized via [GMSServices provideAPIKey:...]`.
   - The app's own "meet here" link (`mqnav://open?lat=…&lng=…`) placed the pin on the campus map but drew no route. On cold start it also logged a flutter_map error ("You need to have the FlutterMap widget rendered at least once before using the MapController", `campus_map_view.dart:120`).

   **Update (fixed, uncommitted):** the crash happened because MQ Journey's commit `7bc9894` removed `GMSApiKey` from `ios/Runner/Info.plist` and the Android manifest key, and the merge kept that. Both are restored, and an unkeyed build now falls back to OpenStreetMap instead of crashing (verified in the simulator).

   **To capture it:** put `GOOGLE_MAPS_API_KEY` in `.env` and launch with `./scripts/run.sh`. That script writes the gitignored `ios/Flutter/Secrets.xcconfig`; a plain `flutter run --dart-define-from-file=.env` does **not** key the iOS SDK. Search "library", tap **Waranara Library → Navigate with Google Maps**, wait for the route and step panel, and screenshot. Save it as `02_walking-route.png`. Note that this shows Google's map, so caption it as such.
2. The date of your meeting with Sylvie, and exactly what she said. Don't strengthen her words.
3. Charanya Ramakrishnan's and Prof. Amin Beheshti's roles. This is **not in this repo**; only the Astronomy README acknowledges them. Ideally get their OK before naming them.
4. Astronomy Open Night: that it was used by attendees on the night, what the organisers permitted, and what the App Store copyright line "© 2026 Astronomy Night – FSE Outreach Team" means for ownership.
5. Incubator participation and the conversation with Jane. Not in any repo.
6. That you and Raouf took the 360° panoramas and the façade photos (EXIF is stripped).
7. Whether the Open Day QR posters were ever installed. The repo contradicts itself.
8. Raouf's agreement to the email text and to the name form "Mohammad Raouf Abedini".
9. Who paid for the Apple developer account (if the University did, mention it).

## J. Repo changes recommended before sending
**Done (uncommitted):**
- `README.md:28` now names the University map.
- The onboarding string is fixed in all 35 locales.
- The Google Maps crash is fixed: restored `GMSApiKey` in `Info.plist` and the Android manifest key; added an iOS `maps_config` channel; the Dart gate now trusts the native key.
- CI CocoaPods drift is fixed: pinned CocoaPods to the lockfile version and regenerated the macOS `Podfile.lock`.

| Priority | Change | Why |
|---|---|---|
| ~~Before sending~~ ✅ done | `README.md:28`: stop saying "The maps … are the developers' own work"; name the University map | Contradicted the email; public |
| **Before sending** (same condition) | Consider making `leoalavi/campus-navigation` and `Raoof128/MQ-Journey` private until the University replies | University map and history are publicly redistributed |
| ✅ done | `lib/app/l10n/app_*.arb` "…or **our** detailed illustrated campus view" → "…or the illustrated campus map" | In-app claim of map ownership (first screen of onboarding) |
| ✅ done | Google renderer crash when no Maps key is present | Root cause: `GMSApiKey` removed in `7bc9894` |
| Before a release | Fix the cold-start `mqnav://open?lat=…` MapController error | Found during this audit |
| Before a release | `docs/store/STORE_LISTING.md`: remove "never leaves your device", "step-free entrances", "right entrance" | Inaccurate |
| Before a release | `README.md:43`: drop "pinpointed at the correct entrance" | 6 of 161 |
| Before a release | Unify the copyright holder: `LICENSE`, `README.md:481`, `app_en.arb:1172`, `product_config.dart:26`, `STORE_LISTING.md`, `macos/…/AppInfo.xcconfig:14`, `windows/runner/Runner.rc:96` | Five different forms |
| Before a release | `docs/BRANDING.md` §3: note that the crest remains inside the map rasters | Its current claim is only partly true |
| Optional | One-line correction note at the top of `docs/mq-journey/AGENT.md` and `CHANGELOG.md`, like the README fix | Historical "Open Day companion" wording |
| After the University replies | Apply their decision on the crest, attribution and disclaimer | — |
