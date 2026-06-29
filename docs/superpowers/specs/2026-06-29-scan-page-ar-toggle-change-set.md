# MQ Journey — Scan Page + Map AR Toggle — Change Set

**Branch:** `feat/scan-page-ar-toggle`
**Parent plan:** [QR · Location · Indoor · Map Design Plan](https://app.notion.com/p/MQ-Journey-QR-Location-Indoor-Map-Professional-Design-Plan-Human-Agent-36a17c101db74308b77557a18a8c75e8?pvs=21)

---

## Change A — Scan page hardening

**👤 Why:** `/scan` exists and routes correctly; what's left is making the camera screen robust and complete — clean lifecycle, no battery/privacy leaks, and every failure state rendered rather than dead-ending.

**🤖 Spec:**

- **Lifecycle:** pause the `MobileScannerController` on route-leave / app-background; resume on return. Auto-stop torch on leave so it never lingers after the user navigates away. Use the v7 `pause()`/`resume()` APIs.
- **Torch guard:** torch toggle is only reachable in the **scanning** state. A denied / decode-error / not-on-trail page must never expose the torch button or call `toggleTorch()` on a controller with no active camera.
- **State coverage (§5.1):** ship distinct, localized states for:
  - **requesting-permission** — graceful waiting state while camera permission resolves
  - **scanning** — active reticle + camera preview (existing, unchanged)
  - **decoding** — brief feedback after a decode is received but before validation completes
  - **denied** — explains permission was denied, deep-links to system settings via `_openAppSettings` / `openAppSettings()`
  - **not-on-trail** — QR decoded but `locationId` not in the allowlist; localized "not part of the trail" message, no navigation
  - **decode-error** — garbled payload or unrecognised format; localized error, retry enabled
  - Verify each is reachable, not just defined.
- **Privacy:** no camera frame is written to disk or network (re-assert the §8 falsifier).
- **Dedup note:** Change C owns the deep-link empty-stack fallback. Change A does not add back-navigation logic.

**✅ Done when:**
1. Leaving `/scan` releases the camera and torch; returning re-acquires cleanly.
2. Torch toggle is absent in denied / decode-error / not-on-trail states.
3. Each §5.1 state renders with distinct localized copy.
4. Denied state reaches the system settings deep-link.
5. Privacy falsifier passes: no camera-frame egress (`scripts/check.sh` privacy guard + secret scan green).
6. `flutter analyze` 0, `flutter test` green for all affected files.

---

## Change B — AR view wired into map page (Google-Maps toggle slot)

**👤 Why:** The indoor/AR view is currently reachable only after a scan resolves to a building. Putting it on the map page — in the slot the Google Maps toggle used to occupy — lets people flip between "where is it" (campus map) and "what's it like inside" (AR) as one object seen two ways.

**🤖 Spec:**

- **Toggle shape:** a **two-segment** segmented control on `/map`, positioned in `MapShell`'s top overlay area (between the search bar and filter chips, where `MapShell` already reserves space for overlay controls): **Campus Map | AR**.
  - No third "Indoor stop-list" segment. The stop list is a companion to the 360° viewer, not a standalone destination.
  - An **optional in-view list toggle** inside the AR segment can surface the stop-list-only view (reusing §5.3's fallback rendering and the existing `IndoorStopList` widget) for reduced-motion / read-only users.
- **Campus Map** = the existing `flutter_map` + `CrsSimple` support layer (§5.4). Untouched.
- **AR** = the §5.3 indoor/compass-AR experience. When tapped:
  1. If a building is **already selected/highlighted** on the map → open AR for that building directly (no picker).
  2. Else if **exactly one** P0 trail building has an indoor manifest → open it directly.
  3. Else → show a **lightweight building picker** listing only manifest-backed P0 buildings. Buildings without a manifest are disabled/greyed with a "coming soon" hint. Never blank.
- **Picker source:** intersect P0 trail buildings (`assets/data/open_day_trail.json`) with buildings that have an actual manifest file (`assets/data/indoor/{buildingId}.json`).
- **Degradation:** WebGL-unavailable / no-manifest / AR-unsupported → fall back to stop-list-only view exactly as §5.3. Never blank.
- **Guardrails (non-negotiable per §2):** no routing/turn-by-turn, no Google-Maps duplication, zero network egress for AR/indoor (CSP `default-src 'self'`), no analytics. `scripts/check.sh` privacy guard + secret scan must stay green.

**✅ Done when:**
1. The toggle switches between campus map and AR in-place (no full-page navigation).
2. AR with a selected building shows scene 1 + stops directly (no picker).
3. AR with exactly one manifest building opens directly.
4. AR with multiple manifest buildings shows the picker, never a blank screen.
5. AR with no manifest buildings shows the disabled/greyed picker state.
6. Unsupported device falls back to stop-list-only view without crashing.
7. `scripts/check.sh` privacy guard + secret scan stay green.
8. No routing code added. No Google-Maps duplication.

---

## Change C — Back button empty-stack fallback

**👤 Why:** A user who lands on `/scan` via deep-link or cold-start with an empty navigation stack can't press back — the AppBar arrow disappears, and the OS back gesture exits the app. Every full page must have a predictable exit, especially the camera screen.

**🤖 Spec:**

- Add a **`PopScope`** guard on `/scan`:
  - `canPop: false` when the navigation stack is empty / `/scan` was the initial route.
  - `onPopInvoked` → `context.go('/')` (home) when pop was attempted but blocked.
  - This covers both the AppBar leading control (GoRouter auto-arrow) **and** the Android system back / gesture back.
- Release the camera and dispose the controller on any leave path (ties into Change A's lifecycle — the camera must always stop).
- a11y: 48×48dp target for any on-screen control, semantic label ("Back"), logical focus order.

**✅ Done when:**
1. From `/scan`, the on-screen back control returns to the previous route (normal stack) or home (empty stack).
2. From `/scan`, the OS back gesture returns to the previous route or home.
3. A deep-linked `/scan` returns to `/` home rather than a blank/closed app.
4. Leaving `/scan` always releases the camera and torch (shared gate with Change A).
5. `flutter analyze` 0, `flutter test` green.

---

## Sequencing

1. **A first** — lifecycle + state hardening of `/scan`; no route changes.
2. **C next** — `PopScope` back guard on `/scan`; depends on A's lifecycle being in place.
3. **B last** — map toggle; independent of A/C but heavier and best isolated.

Each change in its own commit (or logical group of commits) matching the project's convention.

---

## Gates of record (unchanged)

- `flutter analyze` — 0 issues
- `flutter test` — all green
- `bash scripts/check.sh` — all gates (including privacy guard + secret scan)
- Per-change ✅ Done-when above

---

## Existing falsifiers (unchanged — re-asserted)

| Falsifier | Behaviour |
|-----------|-----------|
| Duplicate stamp on re-scan | Idempotent — no second write (§7 of parent plan) |
| Camera frame egress | Blocked — privacy guard + secret scan enforce zero egress |
| AR blank on unsupported device | Never — falls back to stop-list-only view (§5.3) |
| Navigation on rejected payload | Blocked — on-trail allowlist checked before route change |
| No indoor manifest | Clean "no indoor preview" state, not a crash |
