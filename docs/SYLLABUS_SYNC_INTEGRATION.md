# Syllabus Sync ↔ Campus Navigation integration contract

Campus Navigation is the **Android + iOS** navigation app in the Syllabus Sync
ecosystem. It has **no web build**. Syllabus Sync (web) can *initiate* a
navigation request, but it either hands off to the installed app or offers the
store listings — never a browser fallback.

## 1. Direction of truth

| Concern | Owner |
|---|---|
| Campus geometry (map raster, projection, pixel calibration) | Syllabus Sync → exported |
| Building records (`buildings.json`) | **Shared, reconciled** — see §5 |
| Canonical building **identity** (which id names which place) | **Campus Navigation** |
| Partner id → canonical id aliases | **Campus Navigation** (`assets/data/building_aliases.json`, generated) |
| Deep-link payload shape | **Campus Navigation** (`lib/features/deep_link/deep_link_contract.dart`) |

Syllabus Sync never needs a copy of Campus Navigation's building table. It sends
the id it already holds; Campus Navigation resolves it.

## 2. Deep-link format

One public entry path, two transports carrying the identical payload:

```
mqnav://open?destination=<buildingId>          # primary — always works once installed
https://mqnavigation.app/open?destination=<id> # enhancement — needs well-known files
```

Payloads, first match wins:

| Parameter | Meaning |
|---|---|
| `destination=<buildingId>` | focus the map on a building |
| `q=<text>` | open the map filtered by a search term |
| `lat=<double>&lng=<double>` | drop a "meet here" pin |
| *(none of the above)* | open the map root |

`io.mqnavigation://callback` and `https://mqnavigation.io/auth/*` are the
**pre-existing Supabase auth links** and are explicitly *not* part of this
contract. Campus Navigation ignores them for navigation purposes.

## 3. Resolution and failure behaviour

`BuildingIdResolver` resolves in this order:

1. exact canonical id (`17WW`)
2. case-insensitive canonical id (`17ww` → `17WW`)
3. partner alias (`1WW` → `AINS`, `21WW` → `MQTH`, …)

An id that resolves to nothing does **not** silently become the map root — the
user asked for a place. It opens the map with the id as a **search term**, so a
name-matched building is still found and a genuinely unknown id shows an honest
empty result. This is what keeps ids minted by a *future* Syllabus Sync release
from dead-ending against an older installed app.

| Case | Behaviour |
|---|---|
| valid destination | building selected on the map |
| aliased destination | resolved to canonical, then selected |
| unknown / future id | map opens searching for that id |
| missing / malformed payload | map root |
| app not installed | Syllabus Sync shows the store chooser (§4) |

## 4. Not-installed fallback

Syllabus Sync attempts `mqnav://open?...` and races the OS switch against a
timer (`lib/campus-navigation/handoff.ts`). If the page is still foregrounded
when the timer expires, nothing handled the scheme, and
`CampusNavInstallDialog` offers exactly two destinations:

* **Download for iOS** — App Store
* **Download for Android** — Google Play

There is deliberately **no web option**. Store URLs live in
`lib/campus-navigation/config.ts`; the iOS listing does not exist yet, so
`CAMPUS_NAV_IOS_STORE_URL` is `null` and that button renders disabled and
labelled "coming soon" rather than linking to an invented URL. Setting
`NEXT_PUBLIC_CAMPUS_NAV_IOS_STORE_URL` is the only change needed when the
listing goes live.

## 5. Building data export

`syllabus-sync/tools/export_buildings.mjs` exports the map raster, projection
metadata and building records into this repo. It is **merge-safe**:

* it never deletes a building Campus Navigation has and Syllabus Sync does not
  (bike racks, smoking areas — 35 records);
* it never drops fields it does not model (`facultyGroup`,
  `studentServicesGroups`, `campusHubGroups`);
* an **aliased** record contributes only its alias, never its geometry —
  `CHAP` (the Chaplaincy) resolves to `10HA` (the building housing it), and
  merging its coordinates would drag that building's marker 353 m;
* hand-tuned overlay values (e.g. `maxZoom`) are preserved with a warning;
* field updates to existing buildings are **opt-in** (`--apply-fields`). The two
  datasets have diverged and Campus Navigation currently holds the richer value
  in ~108 fields, so a blind export would regress the app. Running without the
  flag reports the differences instead of applying them.

Regenerate aliases and check for drift with:

```bash
npm run export:flutter-map-assets
```
