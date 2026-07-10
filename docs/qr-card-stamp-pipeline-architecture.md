# QR → card → stamp pipeline test map

The automated pipeline injects only at `ScannerView.onDetect`, the decoded
camera-result boundary already used by `ScanPage`. Production and tests then
share the same chain:

1. `QrSignatureVerifier` performs strict parsing, declared-key Ed25519
   verification, and the trail allowlist check.
2. `QrScanOrchestrator` enforces single-flight handling, resolves the verified
   trail location, writes a `VisitEvent`, routes to `/location/<id>`, and sets a
   `PendingStampNotice`.
3. `SettingsProgressApiAdapter` persists the local building-code set first and
   mirrors a unique `(user_id, location_id)` row to `open_day_stamps` only for a
   new visit.
4. `LocationCardPage` renders the verified stable ID's content and consumes the
   matching pending notice once.
5. `computeStampAward` resolves the same ID through the real stamp catalogue;
   `StampEarnedSheet` renders only for a new visit, while repeats use the
   localized already-collected acknowledgement.
6. `StampsPassportPage` derives its collected set from persisted visited codes.

Headless CI uses committed public signed payloads and the production public-key
registry. It substitutes deterministic local persistence and a UTC clock, not
verification or reward results. Isolated Supabase/RLS and physical camera/print
lanes remain separately reported because ordinary CI cannot honestly execute
them without staging credentials and devices.
