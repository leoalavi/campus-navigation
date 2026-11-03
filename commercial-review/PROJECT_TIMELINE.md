# Project timeline: Campus Navigation, MQ Journey and Astronomy Open Night

Audited 3 November 2026 against `main` @ `153ae63`, the other GitHub repositories under the same accounts, and the public App Store listing.

**Status labels**
- **VERIFIED FROM REPO**: a commit, file or GitHub record shows it.
- **SELF-DOCUMENTED (sibling repo)**: stated in a README that Leo and Raouf wrote themselves (`leoalavi/MQ-Astronomy-Open-Night-2026`). It is consistent, but it is not independent proof.
- **VERIFIED ONLY IF LEO PROVIDES EXTERNAL EVIDENCE**: plausible, but no repository can prove it.
- **INTERPRETATION**: a reasonable reading of the evidence.
- **NOT VERIFIED**: no evidence found anywhere.

Commit identities: `Raoof999`, `Raoof128` and `Raouf Abedini` are Raouf. `Pouya Alavi Naeini`, `Mohammadpouya Alavi Naeini` and `Leo Alavi` are Leo. Commit counts are not a measure of contribution.

---

| Date | Milestone | Status | Evidence |
|---|---|---|---|
| 2026-03-10 | First commit of the Flutter app ("Phase 0 + Phase 1 foundation") | **VERIFIED FROM REPO** | `e830029` (Raoof999) |
| 2026-03-13 | The four University overlay maps (parking, accessibility, permits, water) are added | **VERIFIED FROM REPO** | `adf6c1a` "add overlay layer system with 4 campus overlays" |
| 2026-03-21 | Syllabus Sync repository created. Campus Navigation's map raster, calibration and building records are later exported from it | **VERIFIED FROM REPO** (GitHub metadata + `docs/SYLLABUS_SYNC_INTEGRATION.md` §1, §5) | `Raoof128/Syllabus-Sync` createdAt 2026-03-21 |
| Mar–May 2026 | Main development period: 319 commits | **VERIFIED FROM REPO** | `git log` by month: Mar 104, Apr 80, May 135 |
| 2026-04-11 | Public GitHub repository `leoalavi/campus-navigation` created; PR #1 merged | **VERIFIED FROM REPO** (GitHub) | `gh repo view`; PR "merge mq_navigation and MQ_Navigation into a single folder" |
| 2026-04-23 | Home hero photo `campus_background.jpg` added | **VERIFIED FROM REPO** | `2b64689`. Photographer **not recorded**; see `CLAIM_VERIFICATION.md` |
| 2026-05-20 | Project report written to the unit's assessment brief. It addresses "Markers" and contains test credentials | **VERIFIED FROM REPO** | `898f57b`; `PROJECT_REPORT.md:35–45` |
| 2026-05-24 | **"Final commit for assignment"** | **VERIFIED FROM REPO** | `2ac9b41` (2026-05-24 20:49 +10:00) |
| — | The assignment was COMP3130 Mobile App Development at Macquarie | **VERIFIED FROM REPO** (self-statement) | `README.md:410,465`; upstream remote `Raoof128/Pouya-Raouf-COMP3130` |
| 2026-05-24 → 06-26 | MQ Journey begins as a fork **from the final assignment commit** | **VERIFIED FROM REPO** | merge-base of `43c8b24` is `2ac9b41`; 258 commits exist only on the MQ Journey side |
| 2026-06-26 | App renamed "MQ Journey"; Google Maps renderer removed | **VERIFIED FROM REPO** | `de29ca5`, `3843d15`, `3f58e1c` |
| 2026-06-28 → 07-27 | Open Day features built: sessions by degree, Your Day, QR scanning, stamps, signed QR codes (07-10), print pack, building photos (07-18), glass UI (07-19) | **VERIFIED FROM REPO** | `1faee71`, `907ad9e`, `98b1e9e`, `3d4c9b6`, etc. |
| 2026-06-29 | Open Day dataset "updated to match 2026 official PDF". The session program is University content | **VERIFIED FROM REPO** | `d715774`; `docs/open-day/open_day_2026_sessions.json` header |
| 2026-07-07 | MQ Journey rebranded with a magenta Open Day 2026 theme, splash and "Open Day 2026 arch shot" photo | **VERIFIED FROM REPO** | `6c1f341`, `118534c`. The source of the arch photo is **not recorded** |
| 2026-07-10 | Automated QR pipeline tests pass; physical device and print QA **"PENDING"** | **VERIFIED FROM REPO** | `dist/mq-journey-open-day-qr-2026/qa/app-flow-report.md`; `docs/print/open-day-qr-physical-qa.md` |
| 2026-08-15 | Macquarie Open Day 2026 (date taken from the dataset) | **VERIFIED FROM REPO** (date only) | `open_day_2026_sessions.json` `"openDayDate": "2026-08-15"` |
| 2026-08-15 | **MQ Journey used or demonstrated at Open Day 2026** | **NOT VERIFIED** | No usage, publication or installation evidence. The QA files say "pending". `docs/BRANDING.md:55` claims codes are "already printed on campus signage", which conflicts with those QA files. |
| — | MQ Journey published to an app store | **NOT VERIFIED** | No store link or release record. `Raoof128/MQ-Journey` is a public GitHub repo only |
| 2026-08-07 | Astronomy Open Night app repository created (Leo and Raouf) | **VERIFIED FROM REPO** (GitHub) | `leoalavi/MQ-Astronomy-Open-Night-2026` createdAt 2026-08-07 |
| — | The Astronomy app took building coordinates from MQ Journey's dataset "read-only" | **SELF-DOCUMENTED (sibling repo)** | Astronomy README, Attribution section |
| — | Astronomy organisers supplied the programme, event map and hero image "with permission" | **SELF-DOCUMENTED** → **needs external evidence** | Astronomy README, Attribution section |
| — | Amin Beheshti, Charanya Ramakrishnan, Liz Hennebry and the Astronomy Open Night team supported the project, "as part of the Scientist Spotlight program" | **SELF-DOCUMENTED** → **needs external evidence** | Astronomy README, Acknowledgements section. **They are not mentioned anywhere in this repository** |
| 2026-09-19 | Astronomy Open Night 2026 event; app "used by attendees on the night" | **SELF-DOCUMENTED** → **VERIFIED ONLY IF LEO PROVIDES EXTERNAL EVIDENCE** | Astronomy README lines 37, 177 |
| By 2026-11-03 | Astronomy Open Night 2026 app is live on the Australian App Store. Seller **Leo Alavi**, category Education, free, 2 ratings | **VERIFIED** (public App Store page, checked 2026-11-03) | apps.apple.com/au/app/astronomy-open-night-2026/id6808865067. Listing copyright reads **"© 2026 Astronomy Night – FSE Outreach Team"** (see the ownership note in `CLAIM_VERIFICATION.md`). Release date not shown |
| — | Astronomy web app at `aon.syllabus-sync.app`; Android build | **SELF-DOCUMENTED** | Astronomy README links. Not independently checked |
| 2026-09-22 | Campus Navigation `main` resumes: new map data and 51 renamed 360° panoramas added, including the 17WW set "from Astronomy Open Night" | **VERIFIED FROM REPO** | `95d649c`; `test/features/indoor/indoor_repository_test.dart:47` |
| 2026-09-22 → 10-03 | Copyright identity briefly "Perky Coders", then changed to "Syllabus Sync" | **VERIFIED FROM REPO** | `dc53816` adds it, `c6821d7` retires it; `test/features/settings/settings_page_test.dart:196–199` |
| 2026-10-03 | MQ Journey merged into Campus Navigation; Open Day becomes opt-in; package renamed `campus_navigation` | **VERIFIED FROM REPO** | `43c8b24` |
| 2026-10-03 | Rebrand to "Campus Navigation"; 2026 Open Day sessions archived; 2027 dataset left empty pending the official program | **VERIFIED FROM REPO** | `c6821d7`, `29ea9b1` |
| 2026-10-05 | README repositioned (Syllabus Sync ecosystem, platform status) | **VERIFIED FROM REPO** | `96863d8` |
| 2026-11 | Archived MQ Journey docs corrected to "independent / student-developed / unofficial" | **VERIFIED FROM REPO** | `153ae63` |
| — | Campus Navigation published on any app store | **NOT VERIFIED (not done)** | `docs/store/STORE_LISTING.md` is drafts; `ProductConfig.privacyPolicyUrl = null` |
| — | Macquarie University Incubator participation; investor conversations (Jane / Incubator contacts) | **NOT VERIFIED**. **VERIFIED ONLY IF LEO PROVIDES EXTERNAL EVIDENCE** | The only "Incubator" mention in any repo is a map location: `assets/data/buildings.json:1526` "MQ Incubator (8 Hadenfeld Avenue)" |

## Conflicts you should not smooth over

1. **Which came first.** Your story says Campus Navigation came from project work and was "later adapted" for Open Day. The repo agrees: MQ Journey forked from the final assignment commit. Do **not** say Campus Navigation "grew out of" Open Day.
2. **Open Day usage.** `docs/BRANDING.md:55` and `android/app/src/main/AndroidManifest.xml:37–39` say the QR codes "are already printed". The QA records say physical testing is pending. Only you know which is true.
3. **Astronomy and Campus Navigation are two-way, not a straight line.** Coordinates went from MQ Journey to Astronomy (per the Astronomy README). Panoramas and a build technique came back from Astronomy to Campus Navigation (`indoor_repository_test.dart:47`, `android/app/build.gradle.kts:28`, `maps_key_resolver.dart:29`). "After Astronomy we continued Campus Navigation" is accurate. "Campus Navigation is the Astronomy app expanded" is not.
4. **Who owns the Astronomy app.** You are the App Store seller, but the listing's copyright line names the "Astronomy Night – FSE Outreach Team". Confirm what was agreed before you describe ownership.
