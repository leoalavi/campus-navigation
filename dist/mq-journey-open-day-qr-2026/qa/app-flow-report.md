# MQ Journey Open Day QR app-flow report

- Date: 2026-07-10 (Australia/Sydney)
- Signing key ID: `mqj-open-day-2026-02`
- Source commit: `9199d2f`
- Automated command: `flutter test test/features/scan/qr/qr_scan_orchestrator_test.dart`
- Automated result: PASS
- Physical device scanner run: PENDING OPERATOR SIGN-OFF

| Location ID | Signature/allowlist | Correct route | First scan new | Repeat no duplicate |
| --- | --- | --- | --- | --- |
| `hadenfeld-10` | PASS | PASS | PASS | PASS |
| `wallys-29` | PASS | PASS | PASS | PASS |
| `wallys-27` | PASS | PASS | PASS | PASS |
| `wallys-23` | PASS | PASS | PASS | PASS |
| `wallys-21` | PASS | PASS | PASS | PASS |
| `wallys-17` | PASS | PASS | PASS | PASS |
| `ondaatje-14` | PASS | PASS | PASS | PASS |
| `wallys-1` | PASS | PASS | PASS | PASS |
| `wallys-25` | PASS | PASS | PASS | PASS |

The automated test uses the app's production parser, bundled public-key registry,
real trail manifest, real signed payloads, scan orchestrator, and local progress
fake. It proves routing and one-shot progress behavior without camera hardware.
It does not claim a physical Android/iPhone camera or printed-paper result.
