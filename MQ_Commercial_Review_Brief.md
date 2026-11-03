# Campus Navigation: evidence brief for Macquarie copyright and commercial review

*An internal working brief prepared from the repository on 3 November 2026 (HEAD `96863d8`). It is meant for you and Raouf, not for forwarding as it stands. The email-ready text is in §10 and §12.*

Legend used throughout:
- **[FACT]**: directly supported by a file or commit in the repo (path given)
- **[INTERPRETATION]**: a reasonable reading of the evidence, not proven by it
- **[CANNOT VERIFY]**: the repo is silent, or the evidence is missing

---

## 0. Read this first: the most important finding

**[FACT] The base campus map in the app is the University's own campus map, reproduced as an image with the Macquarie University crest and wordmark still on it.**

- `assets/maps/mq-campus.png` is 4678 × 3307 px. That is A4 landscape at 400 dpi, so it is very likely a direct rasterisation of the University PDF **[INTERPRETATION]**. It shows the full MQ crest and wordmark in the top-right corner, the University's legend and grid, and the note "Updated November 2025".
- The four overlays (`assets/maps/overlay_parking.png`, `overlay_accessibility.png`, `overlay_permits.png`, `overlay_water.png`, each 3509 × 2481 px) are also University-produced maps. The parking overlay is titled "Parking Map", carries the MQ crest, and reads "Updated September 2025".
- `docs/map_inventory.md` and `docs/SYLLABUS_SYNC_INTEGRATION.md` §1 say the map raster, projection and calibration are **exported from the Syllabus Sync web app**, not drawn in this repo.

Why it matters:

1. It is consistent with what you told the copyright representative ("we used the public campus map PDF as the base"). Say it plainly in the email. It is your strongest point of honesty.
2. It **contradicts** statements in the repo:
   - `README.md:28` says *"The maps, navigation data and 360° imagery are the developers' own work."* The base map and overlays are not.
   - `docs/BRANDING.md` §3 says the university crest was removed. It was removed only from `assets/images/`. It is still inside every map raster.
   - The README and `lib/core/config/product_config.dart` say the app is "not affiliated with… any university". The crest is visible whenever a user pans to the top-right of the campus map.
3. What you created on top of that map is substantial: calibration, coordinates, search, routing, imagery, the UI and the QR system. Describe it as **"an interactive layer built over the University's published campus map"**, not as "a transformed map" or "our own map". The map artwork itself was not transformed.

**Recommendation:** in the email, ask the University directly whether (a) the published map and overlays may be used in the app, (b) the crest must be cropped or masked, or (c) they would prefer you to redraw a neutral base map. Do not crop the crest silently before you send the email. The reviewer should see the true state of the app.

---

## 1. Strongest factual evidence of what the app does

| Evidence | Where |
|---|---|
| Two map renderers: the illustrated campus raster (flutter_map, `CrsSimple`) and Google Maps, with a toggle | `lib/features/map/presentation/widgets/campus/`, `.../google/google_map_view.dart`, `map_mode_toggle.dart` |
| GPS-to-map projection: a 3-point affine "GCP" calibration that converts phone GPS into pixel positions on the campus image | `assets/data/campus_overlay_meta.json`, `lib/features/map/data/mappers/campus_projection_impl.dart`, `test/features/map/campus_projection_test.dart` |
| 161 location records (41 academic, 29 transport, 26 food, 14 services, 14 residential, etc.) with aliases and search tokens | `assets/data/buildings.json`, `lib/features/map/domain/services/building_search.dart` |
| Walking, driving, cycling and transit routes via a server-side proxy, drawn as a polyline on either map, with step instructions and arrival detection (30 m) | `supabase/functions/maps-routes/index.ts`, `lib/features/map/presentation/controllers/map_controller.dart:209,991`, `route_panel.dart` |
| Compass mode (on-device bearing to destination) | `lib/features/map/presentation/widgets/compass_mode_view.dart` |
| 360° indoor tours: 14 buildings, 51 panoramas, bundled Pannellum viewer | `assets/data/indoor/index.json`, `assets/web/indoor_viewer.html`, `lib/features/indoor/` |
| Safety toolkit: emergency dial, AEDs, first aid, torch | `lib/features/safety/` |
| Live metro departures via a TfNSW Open Data proxy | `supabase/functions/tfnsw-proxy/`, `lib/features/transit/` |
| Favourites stored on the device | `lib/features/favorites/` |
| Optional Open Day layer: sessions by degree, Your Day, signed-QR scanning (Ed25519, verified offline), location cards, stamps passport | `lib/features/open_day/`, `lib/features/scan/`, `docs/qr-card-stamp-pipeline-architecture.md` |
| Deep-link contract (`mqnav://open?destination=…`) | `lib/features/deep_link/deep_link_contract.dart` |
| 35 locales, including RTL | `lib/app/l10n/` |
| Automated tests (≈150 test files) and CI | `test/`, `.github/workflows/ci.yml`, `scripts/check.sh` |

## 2. What it does that a static PDF cannot

1. **Search.** Type "18WW", "library" or a school name and the map jumps to the location. Aliases and search tokens are in `buildings.json`.
2. **"You are here".** The live GPS dot is projected onto the campus image using your own calibration.
3. **Directions.** Turn-by-turn walking routes drawn on the campus map, with step instructions and an arrival prompt.
4. **A look inside before arriving.** 360° panoramas of entrances, lobbies and lecture theatres.
5. **Overlays the user can switch.** Parking, accessibility, permits and water appear as layers on one map instead of separate PDFs.
6. **Context a PDF lacks:** live metro times, one-tap safety contacts, saved places, 35 languages.
7. **Event mode.** Scanning a printed QR code at a building opens that building's card, panorama and map location.

## 3. What you created yourselves, and what you did not

| Area | Created by you? | Basis / caveat |
|---|---|---|
| **Interactive functionality** (search, selection, sheets, favourites, compass, overlays toggle) | **Yes [FACT]** | All Dart code under `lib/`. MIT-licensed, © Raouf Abedini and Leo Alavi (`LICENSE`). |
| **Coordinate / location mapping** | **Yes [FACT]**, with a caveat | The pixel coordinates (126 records have `campusX/Y`), lat/lng and the GCP calibration are your work. **Caveat:** per `docs/SYLLABUS_SYNC_INTEGRATION.md` they were produced in the Syllabus Sync web app and exported here. `gridRef` values (e.g. "N20") copy the University map's own grid. |
| **Navigation / routing** | **Partly [FACT]** | You built the proxy, the request/response normalisation, polyline drawing on the campus raster, step UI, arrival detection and compass. **The route paths themselves are calculated by Google Routes API and OpenRouteService** (`maps-routes/index.ts:13,15`). Do not imply you built a campus path network or a pathfinding engine. |
| **Location data** | **Mostly yes [FACT]** | You compiled, named, aliased and categorised the 161 records. Building names, street addresses and some descriptions reflect University facts and sources. The 9 Open Day card descriptions were "web-researched" (commit `3d4c9b6`). |
| **Imagery: 360° panoramas** | **Claimed yes [CANNOT VERIFY from repo]** | 51 equirectangular panoramas (commit `3400638`: "Ingest 31 equirectangular photos (8192×4096)"). EXIF camera data has been stripped, so the repo cannot prove who took them. Your own originals with metadata would prove it. |
| **Imagery: building façade photos** (`assets/photos/`, 9 files) | **Claimed yes [CANNOT VERIFY]** | Commit `3d4c9b6` calls them "real facade photo[s]" but gives no source. No EXIF. |
| **Home hero photo** (`assets/images/campus_background.jpg`) | Described as "an original photograph" (`docs/BRANDING.md` §5) | It shows campus signage with small University logos. `BRANDING.md` itself recommends replacing it. |
| **Base map and overlays** | **No [FACT]** | University-produced. See §0. |
| **UI/UX** (glass design system, custom tab bar, shader, onboarding, startup screen, icons) | **Yes [FACT]** | `lib/shared/widgets/glass_*`, `shaders/glass_refraction.frag`, `tool/branding/`. The red accent colour is close to MQ red. Classes are named `MqColors` etc. (internal only, `BRANDING.md` §2). |
| **Open Day session schedule** (2026, now archived) | **No [FACT]** | `docs/open-day/open_day_2026_sessions.json` says: "Source: the official 2026 info-sessions PDF". This is University content. |
| **Signed-QR system, posters and print pack** | **Yes [FACT]** | `tool/open_day_qr/`, `QR Codes/`, `dist/mq-journey-open-day-qr-2026/` |

> **Wording note:** you described the imagery as "3D-style". The repo shows **360° equirectangular panoramas viewed in an interactive panorama viewer** and ordinary façade photos. Call them "360° panoramic photos". There are no 3D models.

## 4. Campus Navigation, the Open Day work (MQ Journey) and Astronomy Open Night

**[FACT]**
- **Campus Navigation** began as a Flutter app. The first commit is `e830029` (10 March 2026, Raouf). The upstream remote is `Raoof128/Pouya-Raouf-COMP3130`, and the README says it was the **COMP3130 Mobile App Development major project** at Macquarie.
- **MQ Journey** was "the Open Day visitor app built from the same codebase" (merge commit `43c8b24`, 3 October 2026). It was merged into Campus Navigation and its history kept. Its docs are archived in `docs/mq-journey/`.
- MQ Journey brought across: the 2026 Open Day dataset, the QR scanner, location cards, the stamps passport, and 360° hotspots for 14SCO, 17WW and MQTH.
- **Astronomy Open Night** is a **separate, sibling project**. It is not in this repository. It is referenced in only four places:
  - `test/features/indoor/indoor_repository_test.dart:47`: "17WW came from Astronomy Open Night: wider coverage, no hotspot graph."
  - `test/features/indoor/indoor_catalogue_test.dart:9,50`: the 360° catalogue migration came from "MQ Journey / Astronomy Open Night", and a test checks that **no Astronomy Open Night event content** (passport, stamps, "solar system walk") is included.
  - `android/app/build.gradle.kts:28` and `lib/features/map/data/services/maps_key_resolver.dart:29`: a build/key-resolution technique was copied from "the sibling astronomy project".

**[INTERPRETATION]** The direction of flow in the repo is: Campus Navigation codebase → MQ Journey (Open Day fork) → merged back. Some 360° imagery and build techniques were shared with a separate Astronomy Open Night app.

**[CANNOT VERIFY]** That Campus Navigation "grew out of" Open Day work. The repo shows the reverse: the navigation app came first (March 2026) and MQ Journey was built from it. The repo also cannot show that Astronomy Open Night was "adapted from" this app. Safer wording: *"The same codebase and campus data were used for an Open Day companion app (MQ Journey), and some of our 360° imagery and techniques were shared with a separate app we built for Astronomy Open Night."*

## 5. Evidence of real use at a Macquarie event

**The repository does not prove event use. Be careful here.**

| Item | What it shows |
|---|---|
| `QR Codes/`, `dist/mq-journey-open-day-qr-2026/`, `release/…zip` | **[FACT]** Print-ready, signed QR posters for 9 buildings were produced for Open Day 2026 (15 August 2026). |
| `docs/open-day/open_day_2026_sessions.json` | **[FACT]** The 2026 session program was loaded and archived "after the event". |
| `docs/print/open-day-qr-physical-qa.md` | **[FACT]** "Status: PENDING PHYSICAL EXECUTION". Physical scanning was never recorded as passed. |
| `dist/.../qa/app-flow-report.md`, `artifacts/qr-card-stamp-pipeline/android-device-report.md` | **[FACT]** Automated tests passed. Physical device runs: "PENDING". |
| `docs/BRANDING.md:55`, `AndroidManifest.xml:37` | They state the codes "are already printed on campus signage". **This conflicts with the QA files.** |

**[CANNOT VERIFY]** Whether the posters were installed, whether the app was used or demonstrated at Open Day 2026 or Astronomy Open Night, whether anyone at the University authorised that, or how many people used it. There are no usage numbers, and by design there is no analytics.

If the app *was* used at those events, back it up with evidence from outside the repo: photos of the posters in place, emails from event organisers, a staff contact who saw it. Otherwise say "prepared for" rather than "used at".

## 6. Repository material useful for the reviewers

**Send or offer:**
- `README.md` lines 26–28 and the footer (independence statement); `docs/BRANDING.md` (shows you thought about brand independence, and what still needs a decision)
- `docs/PRIVACY.md`, `docs/SECURITY_POSTURE.md`, the Google Play data-safety table in `docs/store/STORE_LISTING.md` (no accounts, no analytics)
- `docs/ARCHITECTURE.md`, `docs/map_inventory.md` (where data and APIs come from)
- `LICENSE` (MIT, © 2026 Raouf Abedini, Leo Alavi)
- `test/product/brand_independence_test.dart` (an automated guard against "official app" wording)
- the Open Day QR contact sheet: `QR Codes/Contact Sheet/MQ Journey Open Day QR Contact Sheet.png`
- the git history as a dated development record (first commit 10 March 2026; 592 commits on `main`)

**Do not send:**
- `PROJECT_REPORT.md`. It describes sign-in and accounts that no longer exist, and it contains test-account credentials.
- `docs/mq-journey/README.md`. It says MQ Journey was *"the official companion app for Macquarie University Open Day 2026"* and was themed on the Open Day "(OPEN DAY)us" campaign identity. See §8.
- the `screenshots/` folder. These are May 2026 captures of an older UI, and `01_login_page.png` shows a login screen that has since been removed.

## 7. Recommended screenshots (take fresh ones from the current build)

Use one phone, light mode, English, and a clean status bar. Turn Open Day off except for shot 6.

| # | Screen / state to capture | Why it is useful | Filename | Caption |
|---|---|---|---|---|
| 1 | **Navigation tab, Campus Map renderer, zoomed out** so the whole campus and the **blue GPS dot** are visible, with one building selected (marker plus its info sheet) | Shows honestly that the University's published map is the base, and what you added on top (live position, markers, selection sheet) | `01_campus-map_interactive-layer.png` | "Our interactive layer (live location, selectable buildings and information sheets) shown over the University's published campus map." |
| 2 | **An active walking route** on the Campus Map, e.g. from Macquarie University Metro to 1 Central Courtyard (1CC), with the route line and the step-by-step panel open | The clearest thing a PDF cannot do | `02_walking-route_turn-by-turn.png` | "Walking directions drawn on the campus map, with step-by-step instructions and arrival detection." |
| 3 | **Search sheet** with a short-code query such as `18WW` or `library`, showing several matched results | Shows your own location data (aliases, codes, categories) | `03_building-search_aliases.png` | "Search across 161 campus locations by name, building code or common nickname." |
| 4 | **360° indoor tour**, e.g. 1 Central Courtyard (12 scenes) or 14 Sir Christopher Ondaatje Ave (7 scenes), with the scene rail visible | Your own photography, used interactively | `04_360-indoor-tour.png` | "360° panoramic photos we captured on campus, letting visitors preview entrances and lecture theatres before arriving." |
| 5 | **Settings → About**, showing the app name, developers, the line "An independent app. Not affiliated with, endorsed by, or published by any university.", and the copyright line | Shows the commercial reviewer that you do not present it as official | `05_about_independence-notice.png` | "In-app About screen identifying the developers and stating the app is independent of the University." |
| 6 *(optional)* | **Open Day location card** after scanning one of the printed 2026 QR codes (e.g. 10 Hadenfeld Ave), showing the photo, description, 360° button and "View on Campus Map" | Shows the event use case and the signed-QR system | `06_open-day-qr-location-card.png` | "Optional Open Day mode: scanning a building's QR poster opens its information card, panorama and map location." |

Tips:
- For shot 1, **do not crop out the crest**. If the reviewer asks, you can show them that you intend to remove or replace it.
- In shot 6, the bundled 2027 schedule is intentionally empty. If a "pending" banner appears, it is accurate; leave it.
- If you also attach the Google Maps view, label it as Google's map so it is not confused with your work.

## 8. Do NOT claim (inaccurate, ambiguous or overstated)

| Don't say | Why | Say instead |
|---|---|---|
| "We transformed the PDF into our own map" / "the maps are our own work" | The raster is the University's map, crest included (§0) | "We used the University's published campus map as the base image and built an interactive layer over it." |
| "3D imagery" | They are 360° panoramas | "360° panoramic photos" |
| "Our own routing / campus pathfinding" | Routes come from Google Routes and OpenRouteService | "Directions are calculated by established routing services and displayed on the campus map within our app." |
| "Every building pinpointed at its entrance" (`README.md:43`) | Only **6 of 161** records have entrance coordinates | "161 campus locations, mapped to their position on the campus map" |
| "Walking routes that use step-free entrances" (`STORE_LISTING.md`) | No code does this. The accessibility overlay is an image | Drop it, or say "an accessibility overlay" |
| "Your location never leaves your device" (`STORE_LISTING.md`) | The same file's data-safety table says location is sent to the backend for routes and transit | "Location is used only to answer your request and is not stored." |
| "Used at Open Day 2026 / Astronomy Open Night" | No usage evidence in the repo; physical QA is still "pending" (§5) | "Prepared for Open Day 2026…" unless you have outside evidence |
| "Official", "endorsed", or "for Macquarie" | No University approval is recorded anywhere | "Independent app for the Macquarie campus community" (see §12) |
| "The copyright representative approved it" | She said, informally, that the concept appears acceptable from a copyright perspective | "…indicated the concept appeared acceptable from a copyright perspective and referred us to the Commercial Officer" |
| "Campus Navigation grew out of the Open Day app" | Git history shows the opposite order | §4 wording |
| "Published / on the app stores" | Store listings are drafts; the privacy-policy URL is `null`; iOS is not fully verified | "Ready for store submission, pending this review" |
| Any user numbers, downloads or feedback | None exist in the repo | Nothing |
| "The University's web map requires SSO and has no routing" (`PROJECT_REPORT.md`) | Unverified, and disparaging to the people you are asking | Omit |

## 9. Relationship to Syllabus Sync

**[FACT] The repo positions it as part of the Syllabus Sync ecosystem, but technically it is a standalone app.**

Evidence of a formal link:
- README title: "Campus Navigation — Mobile Campus Wayfinding **for Syllabus Sync**"
- `ProductConfig.copyrightHolder = 'Syllabus Sync'`, so the in-code copyright reads "© 2026 Syllabus Sync"
- Settings → About contains the row "Part of the Syllabus Sync ecosystem" with the Syllabus Sync logo
- the map raster, calibration and building records are exported from the Syllabus Sync codebase (`docs/SYLLABUS_SYNC_INTEGRATION.md` §1, §5)
- a deep-link contract, and an optional shared Supabase backend

Evidence of independence:
- "can be launched and used entirely on its own — no Syllabus Sync account or session is required" (README §Ecosystem)
- separate repository, separate licence, separate store identity

**[INTERPRETATION]** The best description is "a separate app that is linked to Syllabus Sync": a sister project by the same developers. There are **two problems to fix before the commercial review**:
1. **The copyright holder is inconsistent.** `LICENSE` says "Raouf Abedini, Leo Alavi". The README says "Leo Alavi and Raouf Abedini". `app_en.arb` and the store listing say "Leo Alavi and Mohammad Raouf Abedini". `ProductConfig` says "Syllabus Sync", which is not a legal entity, as its own comment notes. The Commercial Officer will want **one** answer.
2. If you mention Syllabus Sync, the University will reasonably ask about that project too. Decide together whether the email names it.

## 10. Development history for the email

> Campus Navigation was started in March 2026 by Raouf Abedini and me as our major project for COMP3130 (Mobile App Development) at Macquarie. We have continued developing it since the unit finished.
>
> The app uses the University's published campus map as its base. We calibrated it against GPS so that a phone's location appears on it. We then mapped over 160 campus locations with names, building codes and search aliases. We added walking directions displayed on the map, 360° panoramic photos we captured inside and outside campus buildings, and a safety and transport panel.
>
> In mid-2026 we adapted the same codebase into an Open Day companion app, MQ Journey, for the August 2026 Open Day. It included signed QR-code posters for nine buildings. Some of our 360° imagery and techniques were also shared with a separate app we built for Astronomy Open Night. In October 2026 we merged the Open Day features back into Campus Navigation as an optional mode, so there is now a single app for students, staff and visitors.

Edit the third paragraph to match what actually happened at the events. Say "was used at" **only** if you have evidence (§5).

## 11. Main technologies

- **App:** Flutter 3.44 / Dart 3.11, Riverpod 3 (state), GoRouter (navigation)
- **Maps:** flutter_map (campus image renderer) and google_maps_flutter (Google renderer); geolocator; flutter_compass
- **Backend:** Supabase (Postgres, Deno Edge Functions as API proxies)
- **External services:** Google Routes and Places APIs, OpenRouteService (walking routes), TfNSW Open Data (transport)
- **360° viewer:** Pannellum (open source), bundled in the app
- **QR security:** Ed25519-signed QR payloads, verified on the device
- **Other:** Firebase Cloud Messaging (notifications), flutter_secure_storage, 35-locale localisation, GitHub Actions CI, Maestro end-to-end tests

## 12. Wording that could imply an official University product

| Risky | Where / why | Safer |
|---|---|---|
| "Macquarie University Campus Navigation app" / "the MQ app" | Reads as a University product name | "Campus Navigation, an independent app for the Macquarie campus" |
| "for Macquarie University" | Implies commissioning | "for students, staff and visitors at Macquarie's North Ryde campus" |
| "official companion app for Macquarie University Open Day 2026" | `docs/mq-journey/README.md` and the archived MQ Journey docs, **in a public repo** if `github.com/leoalavi/campus-navigation` is public | Edit or remove this before review. Describe it as "an independent companion app we built for Open Day 2026" |
| "(OPEN DAY)us" campaign identity, magenta theme | Same archived docs: University campaign branding | Remove the reference |
| "partnership", "collaboration with the University", "approved" | Nothing in the repo supports these | Don't use them |
| "MQ Journey", `mqnav://`, `io.mqjourney://`, `mqnavigation.app`, the `MqColors` classes | "MQ" prefixes in names, URLs and domains suggest affiliation. `BRANDING.md` keeps them for compatibility | Mention that you are willing to rename public-facing identifiers (domain, schemes) if the University asks |
| The crest in the map raster, and the hero photo with University signage | Visual affiliation | Ask the University (§0); `BRANDING.md` already flags the hero photo |
| "release the app to the University community" | Could sound like a University release | "make the app publicly available on the App Store and Google Play" |

Suggested independence sentence for the email:
> "Campus Navigation is an independent student-developed app. It is not an official Macquarie University product, and we would not present it as one. We are seeking the University's guidance on the use of its published campus map and on any conditions for a public release."

---

### Open questions only you can answer
1. Who took the 360° panoramas and façade photos? Keep the originals with EXIF as proof.
2. Were the QR posters actually installed, and was the app used at Open Day 2026 and Astronomy Open Night? Who approved that on the University side?
3. Is `github.com/leoalavi/campus-navigation` public? If so, the "official companion app" text in `docs/mq-journey/` is already visible to anyone.
4. Does Macquarie's student IP policy apply to work that began as COMP3130 coursework? The Commercial Officer will probably ask. The repo cannot answer it.
5. Which single legal owner and copyright line do you and Raouf want to use?
