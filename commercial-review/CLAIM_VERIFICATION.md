# Claim verification and repository re-audit

Audited 3 November 2026 against `main` @ `153ae63` (clean). Sources checked: this repository and its full git history (all branches, including `stash/mqj-*`); GitHub metadata for `leoalavi/campus-navigation`, `Raoof128/MQ-Journey`, `Raoof128/Syllabus-Sync`, `leoalavi/syllabus-sync` and `leoalavi/MQ-Astronomy-Open-Night-2026` (README only); and the public App Store page for the Astronomy app.

Labels used below: **VERIFIED** · **SELF-DOCUMENTED** (in a README you wrote) · **NEEDS LEO'S EVIDENCE** · **INTERPRETATION** · **NOT SUPPORTED**

---

## 1. Re-audit: where things are

| Area | Finding | Path |
|---|---|---|
| Structure | Flutter app, organised by feature: map, indoor, search, open_day, scan, safety, transit, favorites, settings, deep_link, notifications, timetable | `lib/features/*`, `README.md:280–310` |
| Router | 3-tab shell (Home / Navigation / Settings), plus a Scan tab when Open Day is on; `/open` deep-link route | `lib/app/router/app_router.dart`, `docs/route_matrix.md` |
| Map assets | University base map and 4 University overlays | `assets/maps/` (see `IP_AND_ASSET_BOUNDARY.md`) |
| Location data | 161 records; 126 with map pixel positions; 6 with entrance coordinates; 6 with Google Place IDs | `assets/data/buildings.json` |
| 360° imagery | 14 buildings, 51 panoramas | `assets/data/indoor/index.json` |
| Routing | Supabase Edge proxy to Google Routes and OpenRouteService | `supabase/functions/maps-routes/index.ts:13,15` |
| Arrival detection | 30 m threshold | `lib/features/map/presentation/controllers/map_controller.dart:209,991` |
| Tests | 120 test files, ~650 `test`/`testWidgets` cases; CI on GitHub Actions; Maestro E2E flows | `test/`, `.github/workflows/ci.yml`, `maestro/` |
| Current docs | README, architecture, privacy, security, inventories, branding, store listing (drafts), Syllabus Sync contract | `README.md`, `docs/*.md`, `docs/store/` |
| Historical docs | COMP3130 project report; archived MQ Journey docs (corrected to "independent" in `153ae63`); long agent changelogs | `PROJECT_REPORT.md`, `docs/mq-journey/`, `AGENT.md`, `CHANGELOG.md` |
| PRs | `leoalavi/campus-navigation`: 1 PR (#1, merged 2026-04-11). PRs #9–#11 in the history were on `Raoof128/MQ-Journey` | `gh pr list`; merge commits `d88ad94`, `7ea0eff`, `59d97bc` |
| Screenshots in repo | `screenshots/` is from May 2026 (old UI, including a login page that no longer exists). `docs/mq-journey/screenshots/` is MQ Journey-era | — |
| Branding guard | Automated test bans "official app" wording in UI strings and the crest file in `assets/images` (but **not** the crest inside the map rasters) | `test/product/brand_independence_test.dart:53,71` |
| Deployment / store | Store copy is **drafts**; privacy-policy URL `null`; Android signing and Fastlane configured; no store link anywhere | `docs/store/STORE_LISTING.md`, `lib/core/config/product_config.dart:55`, `android/fastlane/` |
| Web | "Prepared for a future release but is not deployed" | `README.md:268` |
| Repo visibility | `leoalavi/campus-navigation` is **PUBLIC**, as are `Raoof128/MQ-Journey` and the Astronomy repo | GitHub |

## 2. Your requested story, claim by claim

| # | Your claim | Status | Basis |
|---|---|---|---|
| 1 | Campus Navigation originated from our university project work | **VERIFIED** | `README.md:410`; commit `2ac9b41` "Final commit for assignment"; `PROJECT_REPORT.md` addresses "Markers" |
| 2 | Later adapted for Open Day through MQ Journey | **VERIFIED** (that it was adapted) | MQ Journey forked from `2ac9b41`; merge `43c8b24` |
| 3 | Charanya Ramakrishnan and Prof. Amin Beheshti supported us and helped provide opportunities | **SELF-DOCUMENTED → NEEDS LEO'S EVIDENCE** | Not in this repo. The Astronomy README acknowledges "Amin Beheshti, Charanya Ramakrishnan, Liz Hennebry and the whole Astronomy Open Night team… for their support, guidance and encouragement… as part of the Scientist Spotlight program." Nothing links them to Campus Navigation or Open Day. |
| 4 | We were given the opportunity to work on the Astronomy Open Night app | **SELF-DOCUMENTED → NEEDS LEO'S EVIDENCE** | Astronomy README: "the chance to contribute"; "the organisers specifically asked for clearer guidance…" |
| 5 | The Astronomy team supported us | **SELF-DOCUMENTED → NEEDS LEO'S EVIDENCE** | Same acknowledgement; organisers supplied programme, map and hero image "with permission" |
| 6 | That project was published | **VERIFIED** for the App Store | App Store AU listing id6808865067, seller Leo Alavi, live on 2026-11-03. Web/Android links are self-documented only. |
| 7 | It was used in connection with the event | **SELF-DOCUMENTED → NEEDS LEO'S EVIDENCE** | Astronomy README: "used by attendees on the night", event 19 September 2026. The App Store shows 2 ratings, which does not prove event use. |
| 8 | Astronomy gave real-world deployment experience for a Macquarie event | **INTERPRETATION** (fair if 6 and 7 hold) | — |
| 9 | After that we continued Campus Navigation | **VERIFIED** | `main` resumes on 2026-09-22 (three days after the event), with panoramas partly from the Astronomy work |
| 10 | We have been involved with the Macquarie University Incubator | **NOT SUPPORTED by any repo → NEEDS LEO'S EVIDENCE** | The only "Incubator" mentions are a map location (`buildings.json:1526`) |
| 11 | We discussed investor/commercialisation pathways with Jane / Incubator contacts | **NOT SUPPORTED → NEEDS LEO'S EVIDENCE** | No mention of Jane, James Linton, investor, pitch or founder anywhere |
| 12 | We intend to continue after graduation | **Statement of intent.** Yours to make | README roadmap supports ongoing development (`README.md:425–433`) |
| 13 | Linked to Syllabus Sync but standalone; not owned by a registered company | **VERIFIED** | README ecosystem section; `product_config.dart:23–26` "Deliberately no legal-entity suffix… none exists" |

## 3. Astronomy Open Night

- **Code-level relationship:** loose, two-way, and documented only in comments, tests and the Astronomy README.
  - Astronomy → Campus Navigation: the 17WW panorama set ("17WW came from Astronomy Open Night", `test/features/indoor/indoor_repository_test.dart:47`); the `.env`-to-Gradle key technique (`android/app/build.gradle.kts:28–29`); runtime Maps-key resolution (`lib/features/map/data/services/maps_key_resolver.dart:29`).
  - MQ Journey → Astronomy: "Building coordinates were sourced from… MQ Journey, inspected read-only" (Astronomy README, Attribution section).
  - A guard test ensures no Astronomy **event** content (passport, stamps, "solar system walk", "open night") is in Campus Navigation's tours (`test/features/indoor/indoor_catalogue_test.dart:50–67`; `test/product/brand_independence_test.dart:208–218`).
- **Deployment:** App Store listing **verified**. Web and Android are self-documented.
- **Event use:** **self-documented only.**
- **Organiser references:** Astronomy README (self-authored): programme, event map and hero image (Aleix Roig) supplied by organisers "with permission".
- **Charanya / Prof. Beheshti:** Astronomy README acknowledgements only. **Zero references in this repository.**
- **Screenshots, posters, QR codes, events:** none in this repo for Astronomy. Its own repo describes a QR passport rally; not checked further.
- **Ownership flag:** the App Store copyright line is **"© 2026 Astronomy Night – FSE Outreach Team"**, while the seller is Leo Alavi. That suggests a University faculty team may be credited with copyright of the Astronomy app. Confirm what was agreed before describing who owns it. This is also exactly the kind of precedent the Commercial Officer may ask about.

## 4. Open Day / MQ Journey

- **What it was:** a fork of the COMP3130 app (forked 2026-05-24, renamed 2026-06-26) built as an Open Day 2026 visitor companion. It added personalised sessions by degree, Your Day, suggested stops, signed QR posters for 9 buildings, location cards with photos, a stamps passport, 360° hotspots, and a magenta Open Day theme. Google Maps was removed during the fork.
- **Merged back (`43c8b24`, 2026-10-03):** Open Day dataset and features; QR scanner with offline signature verification; location cards and photos; stamps; 360° hotspots for 14SCO, 17WW and MQTH; glass UI; tests; Maestro; QR print tooling. MQ Journey's anonymous Supabase session was dropped. Open Day is now **opt-in**.
- **Real Open Day usage:** **NOT VERIFIED.** The QR print pack exists, but physical scanning QA is recorded as "PENDING" (`docs/print/open-day-qr-physical-qa.md:3`; `dist/mq-journey-open-day-qr-2026/qa/app-flow-report.md:7`; `artifacts/qr-card-stamp-pipeline/android-device-report.md:3`). Two other files assert the codes were printed (`docs/BRANDING.md:55`, `AndroidManifest.xml:37–39`).
- **Publication:** **NOT VERIFIED.** No store listing or release.
- **Branding:**
  - Magenta/plum theme referencing the "(OPEN DAY)us" campaign (removed from the docs in `153ae63`).
  - "Open Day 2026" arch photo, from which **the Macquarie logo was digitally removed** (MQ Journey changelog for `118534c`). Not in the current app, but in public history.
  - Earlier docs called it "Macquarie University's Open Day campus companion" (`docs/mq-journey/AGENT.md:241`, `docs/mq-journey/CHANGELOG.md:196`; historical log entries, left unchanged).
- **Say:** "We adapted the app into an Open Day visitor companion (MQ Journey) for Open Day 2026, including signed QR posters for nine buildings, and later merged those features back as an optional mode."
- **Don't say:** "used at Open Day", "the Open Day app", "official", or "for the University's Open Day campaign", unless you have evidence of real use and of who approved it.

## 5. Incubator, investor and commercial history

Searched every tracked file and every commit message for: Macquarie Incubator, MQ Incubator, James Linton, Jane, investor, commercialisation, pitch, founder, startup, Syllabus Sync. Also checked the Syllabus Sync and Astronomy READMEs.

**Result:** **nothing supports Incubator participation or investor discussions.** "MQ Incubator" appears only as a campus map location. "Commercialisation" appears only as an office name in building data.

The framing you suggested, *"the team has participated in the Macquarie University Incubator and explored future commercialisation/investor pathways"*, may be used **only if you can back it with your own records** (Incubator emails, program acceptance, a meeting invite with Jane). If you use it, keep it this modest. Never imply the University arranged or offered investment.

## 6. Ownership references (all inconsistent)

| Where | What it says |
|---|---|
| `LICENSE:3` | Copyright (c) 2026 Raouf Abedini, Leo Alavi |
| `README.md:481` | © 2026 Leo Alavi and Raouf Abedini |
| `README.md:28` | "independent product developed and maintained by Leo Alavi and Raouf Abedini" |
| `lib/app/l10n/app_en.arb:1172` | © {year} Leo Alavi and **Mohammad** Raouf Abedini |
| `docs/store/STORE_LISTING.md:9–10` | Developer/publisher and © Leo Alavi and Mohammad Raouf Abedini |
| `lib/core/config/product_config.dart:26,31` | copyrightHolder = **'Syllabus Sync'** → "© 2026 Syllabus Sync" (shown in Settings → About per `settings_page_test.dart:198`) |
| `docs/BRANDING.md:3` | "published independently by Leo Alavi and Mohammad Raouf Abedini" |
| `macos/Runner/Configs/AppInfo.xcconfig:14`, `windows/runner/Runner.rc:96` | "Copyright © 2026 io.mqnavigation" (template leftovers) |
| History | "Perky Coders" was the copyright identity from `dc53816` (2026-09-22) to `c6821d7` (2026-10-03), now banned by tests |
| Archived | `docs/mq-journey/README.md` authors "Pouya Alavi Naeini … Raouf Abedini" |
| Astronomy App Store | "© 2026 Astronomy Night – FSE Outreach Team" |

**Recommended temporary wording for the University review** (no entity invented):

> **Campus Navigation is an independent, student-developed app by Leo Alavi and Mohammad Raouf Abedini. It is developed alongside, and linked to, our Syllabus Sync project, which is not a registered company. The source code is ours, published under the MIT licence; the campus map and overlay images in the app are Macquarie University's published maps, used pending the University's guidance.**

Before release, pick one holder for the in-app copyright line. The University may ask why the About screen says "© 2026 Syllabus Sync" when there is no entity of that name. Use one spelling of Raouf's name everywhere.

## 7. Photos and imagery authorship

| Asset | What the repo says | Status |
|---|---|---|
| 51 panoramas | "Ingest 31 equirectangular photos (8192×4096)" (`3400638`); later set added in `95d649c` | **NEEDS LEO'S EVIDENCE** (EXIF stripped). Keep the originals and phone/camera exports. |
| 9 façade photos | "real facade photo" (`3d4c9b6`) | **NEEDS LEO'S EVIDENCE** of who took them |
| Home hero | "original photograph", shows signage logos (`docs/BRANDING.md:98–102`) | **NEEDS LEO'S CONFIRMATION** |
| "3D" imagery | None. They are 360° equirectangular panoramas | Use "360° panoramic photos" |

## 8. Student IP: what the repo shows (not legal advice)

- **Assessed coursework origin: VERIFIED.**
  - `README.md:410`: "originally developed as the COMP3130 Mobile App Development major project at Macquarie University"
  - `PROJECT_REPORT.md` was written to the assignment brief and addresses markers
  - commit `2ac9b41` "Final commit for assignment" (2026-05-24)
  - the upstream repo is named `Pouya-Raouf-COMP3130`
- **Built during coursework (≈ 10 Mar – 24 May 2026, 319 commits):**
  - dual-renderer map
  - University base map and overlays
  - building registry
  - search
  - routing proxy and route display
  - compass
  - safety toolkit
  - transit
  - favourites (then account-based)
  - authentication (since removed)
  - localisation
  - test suite
  - offline map service (`63c7812`, 2026-04-23)
  - first deep-link contract (`b29266a`, 2026-04-24)
- **Added after coursework:**
  - MQ Journey features: Open Day, signed QR, stamps, location cards, 360° hotspot tours, glass UI
  - the current 51-panorama indoor catalogue and tour view (`95d649c`, 2026-09-22)
  - bundled offline campus map
  - debranding and removal of accounts
  - responsive and accessibility fixes
  - 2027 Open Day readiness
- **Mixed origin:** location data and the map calibration were produced in the Syllabus Sync web app (begun 2026-03-21, during the same semester), then exported.
- **Why it may matter:** Macquarie's IP policy for students and coursework, and any unit-specific terms for COMP3130, determine whether the University has any claim to coursework outputs. The before/after split above gives the University a clean basis for that conversation. **This needs University clarification.** Ask; do not assert.
