# Maestro E2E flows — MQ Journey

Device-level UI flows for the Open Day scan → card → map journey, authored with
the `maestro-mobile-testing` skill patterns (iOS post-launch swipe,
`extendedWaitUntil`, screenshots, explicit camera permission).

**iOS bundle id:** `com.pouya.mqnavigation`

## Flows

| File | Tags | What it covers |
|------|------|----------------|
| `smoke_scan_and_map.yaml` | `smoke,ios` | Launch → Home → Scan (camera) screen → Campus Map |
| `campus_map_focus.yaml` | `map,ios` | Map search → select a real venue → map focuses that building (same `selectBuildingById` path the card's "View on Campus Map" button uses) |

## Running

```bash
# Local (needs the app installed on a booted simulator/emulator):
maestro test maestro/smoke_scan_and_map.yaml
maestro test --include-tags smoke maestro/

# Maestro Cloud (real iOS device, no local sim needed):
maestro cloud --api-key "$MAESTRO_API_KEY" --app-file build/ios/iphoneos/Runner.app maestro/
```

Screenshots are written to `~/.maestro/tests/<timestamp>/`.

## Known limitations (important)

These flows deliberately stop short of the full `scan → card → stamp` chain,
because that chain is **not automatable on a simulator**:

1. **QR scan needs a real camera feed.** A simulator has no camera and cannot be
   shown a physical QR, so the decode step can't be triggered by Maestro.
2. **No deep-link shortcut to a card.** `FlutterDeepLinkingEnabled` is `false`
   in `ios/Runner/Info.plist`, so `openLink com.pouya.mqnavigation://location/<id>`
   won't route. The only in-app entry to `/location/:id` is the scanner or the
   stamps passport (which itself needs a prior scan).
3. **Local iOS-sim build is currently blocked** in this environment — the Runner
   scheme resolves no "iOS Simulator" destination (`flutter build ios --simulator`
   fails with "Unable to find a destination matching { platform:iOS Simulator }").
   Use a physical device or Maestro Cloud until that toolchain issue is fixed.

**The full scan → card (photo + description) → stamp → map-focus chain is
verified end-to-end at the logic level** by
`test/features/scan/e2e/scan_to_map_e2e_test.dart` (real signed-QR fixtures,
real trail/buildings/stamp data, real `MapController`). These Maestro flows are
the on-device complement for the parts a device UI can actually exercise.

## Selector note

Selectors use English text labels (the app ships 35 locales but has no test IDs).
Before a first real run, verify labels against the live hierarchy
(`maestro hierarchy`, or the MCP `inspect_screen`) and adjust — the app's onboarding
and scanner screens especially may need selector tweaks.
