# Scan → Celebrate → Collect — Open Day Stamps & Passport (design)

> A scan doesn't just resolve a place — it rewards the walk: a stamp earned, celebrated, and kept in a passport, without ever asking who you are.

**Dual-audience design.** When a visitor scans a printed Open Day QR at one of the 9 canonical locations, the app writes a proof-of-visit stamp, fires a congratulations moment, and adds that location's stamp to a collectible passport. Every feature below carries a **👤 Why** (intent), a **🤖 Spec** (exact, implementable), and a **✅ Done when** (falsifiable gate). This extends the visit-trigger already specified in `docs/superpowers/specs/2026-06-29-qr-scan-indoor-visit-design.md` (§5–§7, Phase 6); the canonical 9-location set is the §7.1 seed in `docs/superpowers/specs/2026-06-30-scanned-location-card-design.md`.

## 0. Scope note

**👤** This plan covers the **reward layer** on top of the existing scan flow: the celebration on a confirmed visit, and the stamp-collection (passport) surface. The scanner, allowlist validation, location card, and the raw stamp write already exist in the shipped QR surface — here we design *what the user sees and collects when a scan counts*.

## 1. Context & problem

**👤** On Open Day, prospective students walk a physical campus dotted with printed QR codes. The scan already resolves to a rich card and silently logs a visit — but nothing celebrates the moment or gives the walk a sense of collectible progress. A lightweight, privacy-clean passport of stamps turns 9 building visits into a game with a clear goal ("collect all 9"), a satisfying per-scan reward, and a reason to keep exploring — all offline-tolerant and without identity.

**Inherited constraints (non-negotiable):** Supabase is system of record · Flutter is presentation-only · zero analytics (CI-enforced) · no login (silent anonymous session) · allowlist-guarded QR · on-device only · 48×48dp targets + 35-locale i18n with RTL for ar/fa/he/ur · reduced-motion honoured.

## 2. Goals & non-goals

| Goals | Non-goals |
| --- | --- |
| Celebrate a confirmed first scan with a congratulations moment + the location's stamp | XP points / point maths / streak logic — partner |
| A collectible passport of the 9 Open Day stamps with clear progress (X / 9) | Leaderboards / social ranking — partner |
| Milestone moments (first stamp · passport complete) | Reward *rules* (what a visit is worth) — partner |
| Idempotent, offline-tolerant stamp state (no duplicate rewards) | A second backend, analytics SDK, or account system |
| Full render against fakes; reduced-motion + screen-reader parity | Geofenced/arrival auto-stamping (reserved, not v1) |

## 3. Ownership & RACI boundary

**👤** This feature sits exactly on the seam. **You own the collectible** — the stamp write, the `VisitEvent`, and the passport screen (proof-of-visit + how it looks and feels). **Your partner owns the economy** — XP numbers, point rules, streaks, leaderboards. Rule of thumb: *if it decides what a visit is worth, it's the partner's; if it decides how a visit is stamped, celebrated, and displayed, it's yours.*

| Capability | Raouf | Partner |
| --- | --- | --- |
| Stamp write to `open_day_stamps` • `VisitEvent` emit | **R/A** | C (consumes event) |
| Congratulations / stamp-earned celebration UI | **R/A** | I |
| Stamps passport / collection screen (`/stamps`) | **R/A** | C (optional reward chip) |
| Progress = distinct locations stamped (X / 9) | **R/A** | I |
| XP points / point maths / streaks | C (emits + renders returned state) | **R/A** |
| Leaderboards / social | I | **R/A** |

> **Vocabulary:** use "stamp" / "passport" in all UI copy. "XP" is the partner's web-side reward layer — never rendered as a number in this surface. When `ProgressApi.watch` streams `rewardEarned: true`, render the partner's badge/chip; never compute it.

> **Existing `OpenDayGamification` service (tech-debt note):** `lib/features/open_day/domain/services/open_day_gamification.dart` already computes a flat 50-XP-per-visit economy and predates this design. It is **not** part of this feature. Leave it in place and do not import it from any stamps/passport code — it likely has other consumers (`visitProgressProvider`, home) and cleaning it up is a partner-owned migration, not this feature's PR. The passport derives progress **only** from `UserPreferences.visitedLocationCodes` (§6), never from `OpenDayGamification`.

## 4. Experience design (screen by screen)

### 4.1 The scan → congratulations moment (`StampEarnedSheet`)

- **👤 Why:** the reward must land in the same beat as the scan — a clear, warm "you did it" with the specific stamp for this place, so the walk feels collectible. It has to feel great with motion on, and equally clear with motion off or a screen reader active.
- **🤖 Spec:** on a confirmed first visit (`recordVisit` returns `isNewVisit == true`, §5/§6), present a modal bottom sheet containing: (1) headline "Congratulations!" + subline "You collected the {Location} stamp"; (2) the location's stamp artwork revealed (scale/Lottie reveal); (3) progress `"{n} of 9 stamps"` with a progress ring; (4) two CTAs — **View my passport** → `/stamps`, **Keep exploring** → dismiss to the card. Fire a one-shot confetti burst on entry. The sheet is triggered exactly once per location by a `StampCelebrationController` keyed on `locationId` (never re-fires on rebuild).
- **✅ Done when:** a first scan of any of the 9 locations shows the sheet with the correct stamp + name + incremented progress; both CTAs route correctly; the sheet fires once per location and never on a re-scan or a widget rebuild.

### 4.2 Re-scan / already-collected

- **👤 Why:** scanning a place you already stamped should acknowledge gently — never a second celebration, never a duplicate reward.
- **🤖 Spec:** if `recordVisit` returns `isNewVisit == false`, skip the celebration; show a subdued localized snackbar/toast "Already collected — {Location}" with a **View passport** action. No confetti, no duplicate stamp row (idempotent no-op per §6).
- **✅ Done when:** a re-scan shows the subdued acknowledgment, writes no duplicate stamp, and never opens the celebration sheet.

### 4.3 Stamps passport / collection screen (`/stamps`)

- **👤 Why:** the passport makes the whole trail visible — a single screen that shows what you've collected and what's left, turning 9 scattered scans into one quest.
- **🤖 Spec:** a grid/passport of the 9 canonical locations (§7.1 seed of the Scanned-Location Card doc). Each cell: **collected** → full-colour stamp artwork + location name + `scanned_at` date; **locked** → greyed silhouette + location name + map ref (a gentle "scan to collect" hint). Header = a progress ring `{n} / 9`. Data source = `UserPreferences.visitedLocationCodes` (local set) reconciled against `open_day_stamps` via `ProgressApi.watch` — **never** `OpenDayGamification` (§3). Optional per-cell partner reward chip when `rewardEarned` is streamed (rendered, never computed).
  - **New route:** `/stamps` does not exist yet in `route_names.dart` / the router — add it as a new pushed route (not a `StatefulShellRoute` tab).
  - **Entry points:** a new "My Stamps" tile in Settings (persistent discoverability, zero shell-nav change), the celebration sheet's "View my passport" CTA, and a deep link. No 4th bottom-nav tab in v1 — that's a permanent nav-footprint cost for a seasonal feature and leans into partner/home-owned territory.
- **✅ Done when:** the screen lists all 9 locations in canonical order; collected vs locked states render correctly against fakes; the progress ring matches the collected count; tapping a collected stamp opens its location card; the Settings tile navigates to `/stamps`; no XP number is shown.

### 4.4 Milestone moments

- **👤 Why:** the first and final stamp are emotional peaks — mark them without inventing a points economy.
- **🤖 Spec:** **first stamp** → the §4.1 sheet adds a one-line "Your Open Day passport has begun" note. **Passport complete (9/9)** → a distinct "Passport complete!" celebration (stronger confetti + a completion badge on `/stamps`). Both are pure UI states derived from the collected count; no partner call required.
- **✅ Done when:** collecting the 1st stamp shows the begin note; collecting the 9th shows the completion celebration + badge exactly once; neither depends on partner code.

### 4.5 Cross-cutting UX standards

- **Accessibility — motion:** when `MediaQuery.of(context).disableAnimations` (reduce-motion) is true, skip confetti + Lottie; show a static stamp with a subtle fade. No flashing at any time.
- **Accessibility — screen reader:** on celebration, call `SemanticsService.sendAnnouncement` (assertive) — "Congratulations. You collected the {Location} stamp. {n} of 9." Locked/collected cells get semantic labels; decorative confetti is `ExcludeSemantics`.
- **i18n:** all copy via ARB keys (camelCase); no concatenated strings; RTL-correct layout + progress ring for ar/fa/he/ur.
- **Privacy:** stamp artwork is a bundled asset (no CDN); the celebration and passport make zero network requests beyond the existing `open_day_stamps` upsert; no analytics package (CI guard blocks the build).

## 5. Interface contracts (reuse + thin additions)

**👤** Almost everything reuses the seam already locked in the parent plan. The only contract change is the `recordVisit` return type (approved amendment below); the rest is new, Raouf-owned pieces reading from a bundled stamp catalogue.

```dart
// AMENDED from the parent plan: recordVisit now returns Future<bool> (isNewVisit),
// surfacing what SettingsController.recordLocationVisit() already computes but the
// adapter previously discarded.
abstract class ProgressApi {
  Stream<VisitedState> watch(String locationId);
  Future<bool> recordVisit(VisitEvent event); // true = confirmed first visit
}

// UNCHANGED from the parent plan:
//   VisitEvent { locationId, buildingId?, scannedAt, source }
//   class VisitedState { final bool visited; final bool rewardEarned; } // rewardEarned = partner

// NEW — Raouf-owned, from a bundled stamp catalogue (NOT partner-provided).
class StampCatalogEntry {
  final String locationId;      // matches open_day_trail.json / open_day_stamps.location_id
  final String title;           // e.g. "1 Wally's Walk"
  final String mapRef;          // e.g. "K27" (first grid ref)
  final String stampAsset;      // bundled artwork, e.g. assets/stamps/wallys-1.png
}

// NEW — Raouf-owned UI coordinator (no partner dependency).
abstract class StampCelebrationController {
  Stream<StampAward> awards;                 // emits once per newly-collected location
  void onVisitConfirmed(String locationId);  // called by the scan flow; dedups by locationId
}
class StampAward {
  final StampCatalogEntry stamp;
  final int collectedCount;
  final int total; // total = 9
  final bool isFirst;
  final bool isComplete;
  const StampAward(this.stamp, this.collectedCount, this.total, this.isFirst, this.isComplete);
}
```

**Blast radius of the `recordVisit` contract change:** `SettingsProgressApiAdapter.recordVisit` (returns the `isNewVisit` bool from `SettingsController.recordLocationVisit`), `FakeProgressApi.recordVisit`, the single caller in `scan_page.dart`, and 3 existing tests (`settings_progress_api_adapter_test.dart` ×2, `fake_providers_test.dart` ×1).

**✅ Done when:** the celebration + passport read identity from `StampCatalogEntry` and progress from `UserPreferences.visitedLocationCodes`; no XP maths or partner code is inlined; a `FakeProgressApi` + a fixture catalogue render every state standalone.

## 6. Data design & persistence

**👤** Your only write remains the stamp; the celebration and progress are derived. XP stays partner-derived from the `VisitEvent` — you never store or count it.

**🤖 Two-tier, local-first.**

1. **Local-first (UI source of truth):** on a confirmed first scan, `SettingsController.recordLocationVisit()` writes the local visited set immediately → returns `isNewVisit = true` → drives the optimistic celebration + progress, offline-tolerant.
2. **Durable mirror:** enqueue one idempotent upsert into `open_day_stamps`; flush when online. First scan only.

```sql
-- migration 20260629000000_add_open_day_stamps.sql (already applied; SELECT/INSERT RLS, no UPDATE)
open_day_stamps (id, user_id, location_id, scanned_at, created_at, unique(user_id, location_id))
-- RLS: using / with check (auth.uid() = user_id); upsert on conflict (user_id, location_id) do nothing
```

- **Trigger:** fire when `recordVisit`'s return value (`isNewVisit`) is `true`; the durable `open_day_stamps` upsert reconciles in the background. This fires instantly and offline, before any network round-trip.
- **Idempotent both tiers:** local set is set-like; remote uses `on conflict (user_id, location_id) do nothing` (`ignoreDuplicates: true`). A re-scan writes neither and never celebrates.
- **Derived state:** `collected = UserPreferences.visitedLocationCodes` reconciled with `open_day_stamps` via `ProgressApi.watch`; `progress = collected.length` out of 9. **Never** derived from `OpenDayGamification` (§3).
- **Existing symbols to wire:** `ProgressApi.recordVisit → SettingsController.recordLocationVisit()` (now returns and surfaces `isNewVisit`; extend to enqueue the upsert only when `isNewVisit` is true); `ProgressApi.watch → UserPreferences.visitedLocationCodes`.

**✅ Done when:** first scan writes the local set + exactly one remote upsert + fires exactly one celebration; re-scan writes nothing and shows the subdued state; an offline first scan celebrates immediately and flushes the queued upsert on reconnect; progress equals the distinct collected count.

## 7. Gamification model (what's in your lane)

**👤** Keep the mechanics that are about collection and celebration; leave scoring to the partner. This avoids double-building the economy while still delivering a game.

| Mechanic | Owner | Notes |
| --- | --- | --- |
| Collectible stamps (1 per location) | **Raouf** | Bundled artwork; maps 1:1 to `open_day_stamps.location_id` |
| Progress / completion (X / 9) | **Raouf** | Derived count; drives the ring + milestones |
| Per-scan celebration + milestones | **Raouf** | UI-only; first stamp + 9/9 complete |
| XP points / point rules / streaks | Partner | Derived from `VisitEvent`; rendered via `rewardEarned` only |
| Leaderboards / social | Partner | Out of this surface entirely |

> **Stamps = 9 (per location), not 16 (per stop).** The `open_day_stamps` unique key is `(user_id, location_id)`, so a stamp is earned per building. Stops remain the AR/360° activity points inside a location, not separately stamped in v1.

## 8. Security & privacy design

**🤖**

- Celebration + passport add no new network calls beyond the existing `open_day_stamps` upsert under anonymous-session RLS (`auth.uid() = user_id`).
- Stamp artwork + Lottie files are bundled assets (no CDN); confetti is a pure-Flutter draw.
- No analytics package may be added (CI privacy guard blocks the build); no PII in the stamp row beyond the anonymous `user_id`.
- Reward gating stays server-truthful: the durable `open_day_stamps` unique constraint is the anti-duplication authority; the local set is only an optimistic mirror.

**✅ Done when:** `scripts/check.sh` privacy guard + secret scan stay green; a network trace of a scan shows only the single stamp upsert.

## 9. Error handling & edge-case matrix

| Case | Behaviour |
| --- | --- |
| First scan, online | Local write + celebration + one remote upsert |
| First scan, offline | Local write + celebration immediately; queue upsert, flush on reconnect |
| Re-scan same location | No write, no celebration, subdued "already collected" |
| Remote upsert fails after local write | Keep optimistic stamp; retry on queue; unique key prevents dupes |
| Reduce-motion on | Skip confetti + Lottie; static stamp + fade; still announce |
| Screen reader on | Assertive congratulations announcement; semantic cell labels |
| Missing stamp artwork | Neutral placeholder stamp; celebration + progress still fire |
| 9/9 reached | Passport-complete celebration + badge, once |

## 10. Testing & Definition of Done

**🤖** All gates under `scripts/check.sh` (analyze 0 · full suite · l10n · privacy guard · secret scan).

- **Unit:** stamp-set derivation from `UserPreferences.visitedLocationCodes`; progress count; `StampAward` `isFirst`/`isComplete` flags; celebration dedup keyed by `locationId`; `recordVisit` returns `true` only on first write, `false` on repeat (covers the amended contract).
- **Widget:** `StampEarnedSheet` renders stamp + name + progress; `/stamps` collected vs locked states against a fake catalogue + `FakeProgressApi`; reduce-motion path renders static; `sendAnnouncement` fires.
- **Integration:** first scan → celebration → passport increments; re-scan → subdued, no increment; offline first scan → celebrate then flush.
- **Falsifiers (must fail loudly):** a second celebration on re-scan; a duplicate `open_day_stamps` row; confetti/Lottie playing while reduce-motion is on; an XP number rendered in this surface; any network call beyond the stamp upsert; any import of `OpenDayGamification` from stamps/passport code.

## 11. Delivery plan & sequencing

**👤** Build inside-out from the existing visit trigger; contracts + fakes first so it's demoable before partner code.

| Milestone | Deliverable | Exit gate |
| --- | --- | --- |
| G0 — Catalogue & contracts | `StampCatalogEntry` • bundled `stamps` catalogue (9 entries) • `StampCelebrationController` • fakes • `recordVisit` contract amendment | Renders standalone |
| G1 — Derivation | Stamp-set derivation + progress + dedup, wired to §6 impls | §6 Done-when |
| G2 — Celebration | `StampEarnedSheet` • confetti/Lottie + reduce-motion + announce | §4.1/§4.5 Done-when |
| G3 — Passport | `/stamps` route + Settings "My Stamps" tile + progress ring | §4.3 Done-when |
| G4 — Milestones | First-stamp note + 9/9 completion + re-scan subdued state | §4.2/§4.4 Done-when |
| G5 — Hardening | a11y, i18n/RTL, edge cases, full gate | §12 acceptance |

## 12. Acceptance criteria

1. `flutter analyze` 0; `flutter test` green; `scripts/check.sh` all gates green (incl. privacy guard + secret scan).
2. First scan of each of the 9 locations → one stamp, one `VisitEvent`, one celebration with the correct artwork + name + progress.
3. Re-scan → no duplicate stamp, no second celebration, subdued acknowledgment.
4. `/stamps` reachable from a new Settings "My Stamps" tile; shows all 9 in canonical order; collected/locked correct; ring matches count; no XP number.
5. Reduce-motion → static, no confetti/Lottie; screen reader → assertive congratulations announcement; RTL verified.
6. Offline first scan celebrates immediately and flushes the queued upsert on reconnect.
7. No analytics; no second backend; no XP maths in widgets; no import of `OpenDayGamification`.

## 13. Risks & mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Double celebration on rebuild/re-scan | Annoying, feels broken | One-shot controller keyed by `locationId`; `isNewVisit` bool + unique constraint (§5/§6) |
| Motion/flash harms accessibility | Excludes users; fails a11y | `disableAnimations` gate; no flashing; assertive announce (§4.5) |
| Ownership creep into XP | Double-built economy | Render `rewardEarned` only; never compute points; never import `OpenDayGamification` (§3/§7) |
| Offline scan loses the reward | Broken on flaky Open Day network | Local-first trigger + queued upsert (§6) |
| Artwork gaps for 9 stamps | Empty-looking passport | Placeholder stamp; author as a content task; surface gaps in PR |
| Stale `OpenDayGamification` service confuses future contributors | Someone wires the passport to the wrong progress source | §3 tech-debt note + explicit falsifier (§10) forbidding the import |

## 14. Decisions log (defaults — overridable by Raouf)

- **Stamp granularity:** per location (9 stamps), matching `open_day_stamps` unique key; stops stay AR-only in v1.
- **Celebration surface:** modal sheet / overlay (not a full route) so it composes over the location card and dismisses back to it.
- **Trigger:** fire when `recordVisit`'s return value (`isNewVisit`) is `true`; the durable `open_day_stamps` upsert reconciles in the background.
- **Vocabulary:** "stamp / passport"; no XP number in this surface (partner web-side).
- **Motion:** confetti (`confetti`) + a Lottie stamp reveal, both auto-disabled under reduce-motion.
- **Route & entry point:** `/stamps` is a **new** route (not previously reserved); reachable via a new Settings "My Stamps" tile + the celebration sheet's CTA + deep link. No 4th bottom-nav tab in v1.
- **`OpenDayGamification`:** left in place, not imported by this feature, logged as tech-debt for a future partner-owned economy migration.
- **`ProgressApi.recordVisit` contract:** amended to `Future<bool>` (isNewVisit), surfacing the existing `SettingsController.recordLocationVisit()` return value instead of discarding it.

## 15. Dependency alignment (verified against 2026 docs)

**👤** Checked against current pub.dev / Flutter docs (Jul 2026); pin the versions below.

| Package / API | Latest (2026) | Action / note |
| --- | --- | --- |
| `confetti` | 0.8.0 (verified publisher, all platforms) | Pin `^0.8.0` for the celebration burst |
| `lottie` | 3.4.0 (Apr 2026) | Pin `^3.4.0` for the stamp-reveal; needs Flutter ≥3.35 / Dart ≥3.9 — fine on the 3.41/3.11 build target |
| Screen-reader announce | `SemanticsService.sendAnnouncement` | Use `sendAnnouncement` — `SemanticsService.announce` is deprecated after v3.35 |
| Reduce-motion flag | `MediaQuery.of(context).disableAnimations` | Gate confetti/Lottie; reflects OS reduce-motion on current Flutter |
| `supabase_flutter` | 2.15.1 | Reuse the anon session + `open_day_stamps` RLS; already pinned in the QR surface |
| `go_router` | 17.3.0 | New `/stamps` route; package already pinned |

**Net:** only two new packages (`confetti`, `lottie`); the stamp write, routing, and auth all reuse the existing pinned stack.

## 16. Appendix

### 16.1 Asset schema — stamp catalogue (target)

```json
// assets/data/open_day_stamps_catalog.json  (Raouf-owned; drives the passport + celebration)
// One entry per canonical location; locationId matches open_day_trail.json + open_day_stamps.
{ "stamps": [
  { "locationId": "hadenfeld-10", "title": "10 Hadenfeld Avenue",            "mapRef": "P6",  "stampAsset": "assets/stamps/hadenfeld-10.png" },
  { "locationId": "wallys-29",    "title": "29 Wally's Walk",                "mapRef": "L11", "stampAsset": "assets/stamps/wallys-29.png" },
  { "locationId": "wallys-27",    "title": "27 Wally's Walk",                "mapRef": "L12", "stampAsset": "assets/stamps/wallys-27.png" },
  { "locationId": "wallys-23",    "title": "23 Wally's Walk",                "mapRef": "L14", "stampAsset": "assets/stamps/wallys-23.png" },
  { "locationId": "wallys-21",    "title": "21 Wally's Walk",                "mapRef": "L15", "stampAsset": "assets/stamps/wallys-21.png" },
  { "locationId": "wallys-17",    "title": "17 Wally's Walk",                "mapRef": "L17", "stampAsset": "assets/stamps/wallys-17.png" },
  { "locationId": "ondaatje-14",  "title": "14 Sir Christopher Ondaatje Ave", "mapRef": "J20", "stampAsset": "assets/stamps/ondaatje-14.png" },
  { "locationId": "wallys-1",     "title": "1 Wally's Walk",                 "mapRef": "K27", "stampAsset": "assets/stamps/wallys-1.png" },
  { "locationId": "wallys-25",    "title": "25 Wally's Walk",                "mapRef": "N12", "stampAsset": "assets/stamps/wallys-25.png" }
] }
```

### 16.2 Celebration wiring (target shape)

```dart
// Fire once per newly-collected location, motion- and screen-reader-aware.
void onStampAwarded(BuildContext context, StampAward award) {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  SemanticsService.sendAnnouncement(
    'Congratulations. You collected the ${award.stamp.title} stamp. '
    '${award.collectedCount} of ${award.total}.',
    Directionality.of(context),
    assertiveness: Assertiveness.assertive,
  );
  showModalBottomSheet(context: context, isScrollControlled: true,
    builder: (_) => StampEarnedSheet(award: award, playEffects: !reduceMotion));
  // StampEarnedSheet: if playEffects -> confetti burst + Lottie reveal; else static stamp + fade.
}
```

### 16.3 Prior art & references (2026)

- Gamified digital passports — conceptual framework: MDPI, Applied Sciences 2026
- Gamification design patterns for engagement: Informatics in Education (academic)
- QR codes for events — check-in & gamification: Visu Network, 2026 · QR code design best practices, 2026
- Accessible notifications / live announcements: Primer accessibility patterns · Flutter accessibility docs · `SemanticsService.sendAnnouncement` API
- Offline-first Flutter + Supabase: Supabase engineering blog
- Celebration/animation packages: `confetti` · `lottie`
