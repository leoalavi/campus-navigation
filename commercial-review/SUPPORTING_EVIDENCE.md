# Supporting evidence: what to send, keep, or hold back

## A. Repository material

| Item | Path / source | Decision | Why |
|---|---|---|---|
| Fresh screenshots 01, 03, 04, 05 | `commercial-review/screenshots/` | **SEND WITH EMAIL** | Current app, iPhone 17 Pro simulator, no personal data |
| Screenshot 06 (Open Day QR card) | same | **SEND (optional)** | Shows the event use case. Contains a University wayfinding sign and one distant, non-identifiable person |
| Disclosure image 07 (crest in the bundled map) | same | **SEND WITH EMAIL** | Shows the University exactly what is in the app |
| Project summary | `commercial-review/PROJECT_SUMMARY.md` | **SEND** (paste into the email or attach as PDF) | Written to be forwarded |
| IP and asset boundary table | `commercial-review/IP_AND_ASSET_BOUNDARY.md` | **KEEP AS BACKUP**; send if asked for detail | Useful for the Commercial Officer, but long |
| Project timeline | `commercial-review/PROJECT_TIMELINE.md` | **KEEP AS BACKUP** | Contains internal notes and conflicts |
| Claim verification, risk checklist, this file | `commercial-review/*.md` | **DO NOT SEND** | Internal working notes |
| `MQ_Commercial_Review_Brief.md` | repo root | **DO NOT SEND** | Internal working file |
| `README.md` | repo | **DO NOT SEND as-is** | Line 28 says "The maps… are the developers' own work" (incorrect) |
| `PROJECT_REPORT.md` | repo | **DO NOT SEND** | Test credentials; describes the removed login; disparages the University's web map |
| `screenshots/` (May 2026) | repo | **DO NOT SEND** | Old UI, includes a login page |
| `docs/mq-journey/*` | repo | **DO NOT SEND** | Archived; historical "official" language in logs |
| `AGENT.md`, `CHANGELOG.md` | repo | **DO NOT SEND** | Internal; mentions official MQ branding work and the logo edit |
| `docs/ARCHITECTURE.md`, `docs/PRIVACY.md`, `docs/SECURITY_POSTURE.md` | repo | **KEEP AS BACKUP** | Good technical depth if IT or privacy staff ask |
| `docs/BRANDING.md` | repo | **KEEP AS BACKUP** | Shows the deliberate debranding, but contains the "crest removed" claim that is only partly true |
| `LICENSE` | repo | **KEEP AS BACKUP** | MIT, © Raouf Abedini, Leo Alavi |
| QR posters and contact sheet | `QR Codes/`, `dist/mq-journey-open-day-qr-2026/` | **KEEP AS BACKUP** | Evidence of Open Day preparation. Posters carry University map grid references |
| QA reports ("PENDING") | `docs/print/…`, `dist/…/qa/`, `artifacts/…` | **KEEP AS BACKUP** | Honest record. Do not present as proof of use |
| Git history (dated commits incl. `2ac9b41` "Final commit for assignment") | git | **KEEP AS BACKUP** | Dates the coursework boundary for the IP conversation |
| Test suite and CI | `test/`, `.github/workflows/` | **KEEP AS BACKUP** | Evidence of engineering quality (≈650 tests) |
| Store listing drafts | `docs/store/STORE_LISTING.md` | **DO NOT SEND** | Contains inaccurate privacy and step-free claims |
| `.env.example`, Supabase config, migrations | repo | **DO NOT SEND** | Configuration; may name project IDs |

## B. External evidence Leo should provide (not in any repo)

Collect these before claiming the related facts. Keep them in a private folder (e.g. `~/Documents/mq-review-evidence/`). **Do not commit them.**

### Charanya Ramakrishnan's support
- [ ] Emails or Teams messages in which Charanya introduces, invites or supports you (Astronomy Open Night or other projects)
- [ ] Any message referring you to the Astronomy team or the Scientist Spotlight program

### Professor Amin Beheshti's involvement
- [ ] Emails, meeting invites or messages showing his role (supervision, introduction, endorsement of your participation)
- [ ] If he supervised or recommended you, his written agreement before you name him in the email

### Astronomy Open Night opportunity, and the team's support
- [ ] The first message inviting you to build the app (who, when)
- [ ] Organiser emails supplying the programme, the event map and the hero image "with permission". This is the permission record the Astronomy README relies on
- [ ] Any message agreeing who owns or publishes the app, and why the App Store copyright line reads "Astronomy Night – FSE Outreach Team"
- [ ] The University event page for Astronomy Open Night 2026 (19 September 2026), especially if it links or mentions the app
- [ ] App Store Connect: the app record, first release date, version history, and units/downloads if visible (for your own reference)
- [ ] Google Play Console or Android distribution record, if any
- [ ] Photos from the night: QR passport posters in place, people using the app, your table or booth
- [ ] Post-event thanks or feedback from organisers or Liz Hennebry

### Open Day 2026 (MQ Journey)
- [ ] Any approval, or contact with Open Day organisers. If none, do not claim University involvement
- [ ] Photos of the nine QR posters installed (or confirmation they never were)
- [ ] TestFlight or any distribution of MQ Journey
- [ ] Whether you took the "Open Day 2026 arch" photo, and why the logo was removed (be ready to explain)

### University support generally
- [ ] Any funding, reimbursement or sponsorship of Apple/Google developer accounts (who paid?)
- [ ] Any invitation to demonstrate or publish the app (Scientist Spotlight, showcases, unit events)
- [ ] Your notes or emails from the meeting with Sylvie (date, what she said), so your email reflects it accurately

### Macquarie University Incubator
- [ ] Program acceptance, registration or attendance records
- [ ] Emails or meeting invites with Jane (and any other Incubator contacts) about investor or commercialisation pathways
- [ ] Anything showing **who** initiated investor discussions. Do not imply the University arranged investment

### Authorship of imagery
- [ ] Original 360° captures with camera EXIF (device, date), for at least a sample of the 51 panoramas
- [ ] Original façade photos for the nine buildings in `assets/photos/`
- [ ] Original of `assets/images/campus_background.jpg`

### Coursework
- [ ] The COMP3130 unit guide or assessment brief (the IP clause, if any)
- [ ] Your submission confirmation date
