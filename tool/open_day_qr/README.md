# Open Day signed QR issuer

The issuer runs offline. Store the Ed25519 private key outside this repository
and expose only its absolute path for the generation command:

```bash
MQJ_QR_SIGNING_KEY_FILE=/absolute/private/path/mqj-open-day-2026-02.pem \
  dart run tool/open_day_qr/generate.dart \
  --trail assets/data/open_day_trail.json \
  --stamps assets/data/open_day_stamps_catalog.json \
  --key-id mqj-open-day-2026-02 \
  --out assets/qr/open_day/2026
```

The key file may be a raw 32-byte Ed25519 seed or an unencrypted PKCS#8 PEM.
Never copy it into the repository, CI, a print pack, or an app bundle. The tool
refuses an in-repository key path. Rotate by adding a new public key ID to the
app before issuing replacement posters.

Print the SVG masters without editing their black modules or white four-module
quiet zone. Keep branding and the human-readable location ID outside the SVG
boundary. Validate every final print on a current Android phone and iPhone in
bright light, shadow, at an angle, and at the intended scanning distance.

Before writing output, the issuer derives the public key and requires an exact
match with the selected key ID in the app registry. It prints only the key ID,
public SHA-256 fingerprint, and `MATCH`; mismatch and unknown IDs fail closed.
The `mqj-open-day-2026-01` public key remains registered for previously issued
codes. New 2026 production assets use `mqj-open-day-2026-02`.

Build the public print pack from the generated SVG masters with
`build_production_pack.py`, then compile `decode_qr.swift` and run
`verify_rendered_assets.py`. Run `verify_production_pack.dart` for the app
parser, signature, allowlist, and mutation-control report. These tools never
need the private key after SVG issuance.
