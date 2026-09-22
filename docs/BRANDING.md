# Brand independence — what was removed, what intentionally stays

Campus Navigation is published independently by **Leo Alavi and Mohammad Raouf
Abedini**. It must never present itself as a university-owned, university-
published or officially endorsed app.

`test/product/brand_independence_test.dart` enforces this automatically. The
exceptions below are why that test has an allow-list rather than a blanket ban.

## 1. Real-world place names — intentionally kept

The app is a map. Map apps name real places. These are the actual, legal names
of physical venues and streets; renaming them would make the app worse at its
job (a visitor searches "Macquarie Theatre", not "The Theatre") and would not
make the product any more independent.

| ID | Display name | Why it stays |
|---|---|---|
| `MQTH` | Macquarie Theatre | Real venue name |
| `HOSP` | Macquarie University Hospital | Real hospital, a separate legal entity |
| `SPORT` | Macquarie University Sport & Aquatic Centre | Real facility name |
| `OBS` | Macquarie Observatory | Real facility name |
| `METS` | Macquarie Engineering & Technical Services | Real unit name |
| `GALEHIST` | Macquarie University History Museum | Real museum name |
| `MACQUARIEC` | Macquarie Centre | Real **shopping centre** — privately owned, not the university |
| `17MW`, `12MW` | Macquarie Walk | Real street name |
| `HEALTHP2` | Macquarie Hospital Parking | Real car park |
| `INCUB` | MQ Incubator | Real facility name |
| `MQV` | MQ Village | Real residences name |
| `WWC`, `HEALTHP1` | MQH Cafe, MQ Health Disability Parking | Real facility names |
| `BIKEF13`, `BIKEF25` | Bike Rack — Macquarie Theatre / Macquarie University Stn | Named after the venue and Metro station they serve |

Two localisation strings are allow-listed for the same reason:

* `calendarJsonLdLocationAddress` — "Balaclava Rd, **Macquarie Park** NSW 2109"
  is a suburb in a postal address.
* `favoriteStopIdHint` — "**Macquarie University** Station" is the legal name of
  a Sydney Metro station.

**No location was renamed.** Nothing in this table was changed; it is recorded
so the decision is visible rather than silent.

## 2. Technical identifiers — classification

Per the migration brief, each legacy identifier is classified **A** (safe to
rename now), **B** (must remain for compatibility) or **C** (support both).

| Identifier | Value | Class | Reasoning |
|---|---|---|---|
| Dart package | `mq_navigation` | **B** | Internal only; never shown to a user. Renaming touches every import in 160+ files for zero user-visible benefit. |
| Android `applicationId` | `io.mqnavigation.mq_navigation` | **B** | Immutable once published. Changing it orphans every existing install and breaks Play upgrades. Never user-visible. |
| iOS bundle ID | `com.pouya.mqnavigation` | **B** | Same constraint. Must be fixed *before* first submission if it is to change at all — see §5 below. |
| Custom URL scheme | `mqnav://open` | **B** | The live Syllabus Sync handoff. Renaming breaks every link already emitted. |
| Legacy URL scheme | `io.mqnavigation://` | **B** | Pre-existing auth/"meet here" links still in the wild. |
| Universal/App Link domain | `mqnavigation.app` | **C** | Works today. A neutral product domain can be added as a *second* associated domain later, keeping both live during migration. |
| Supabase auth link domain | `mqnavigation.io/auth` | **B** | Registered with the backend; unrelated to product identity. |
| Theme class prefix | `MqColors`, `MqSpacing`, … | **B** | Internal Dart symbols. The doc comments no longer claim university brand ownership. |

None of these is visible to a user. Every **public** surface — launcher name,
App Store/Play name, in-app title, About screen, copyright, store listing —
reads "Campus Navigation".

## 3. What was removed

* The **university crest** (`assets/images/mq_logo.png`) — deleted, and the
  Home hero now renders the app's own logo.
* University ownership in **1,079 localisation strings** across 35 locales,
  including transliterated forms (麦考瑞大学, ماكواري, Маккуори, マッコーリー…).
* The **copyright line**, which read "© {year} … Macquarie University".
* **4,095 dead `privacy_*` strings** inherited from the Syllabus Sync web app.
  They described accounts, passwords, TOTP, WebAuthn and cookies that Campus
  Navigation does not have, and were not referenced by any screen.
* The entire **authentication feature** — see §4 of the migration report.
* Doc comments claiming the design tokens were the university's brand system.

## 4. Translation debt

Removing the brand token mechanically from 35 languages produced grammatically
broken text in inflected and RTL locales (`"Wegweiser zum Campus der"`,
`"تطبيقك المرافق ل."`) and silently missed Persian. Rather than ship that, **26
affected keys were set to verified neutral English in every locale.**

Those locales now show English for these strings until a translator revisits
them. The keys are the union of `IDENTITY` and `NEUTRAL` in
`scratchpad/debrand2.py`, and include: `copyright`, `appName`,
`home_brandTitle`, `aboutDesc`, `aboutTitle`, `helpSupport`, `exploreMap`,
`home_welcomeTitle`, `navigateCampus`, `appCompanionDesc`, `safetyShuttleInfo`.

This is deliberate: brand-safe and grammatical beats localised and wrong.

## 5. Still needing a human decision

* **iOS bundle ID `com.pouya.mqnavigation`** carries a personal prefix and the
  old product name. It is the last moment to change it — after the first App
  Store submission it is permanent. A neutral `app.campusnavigation.ios` (or
  similar) would match the product identity.
* **`assets/images/campus_background.jpg`** is the Home screen hero: an
  original photograph, but it shows campus signage including small university
  logos on the signpost. It is our own photo of a public place, which is
  ordinarily fine — but as a full-bleed hero on the first screen it is the
  strongest remaining visual association with the university. Consider
  replacing it before submission.
