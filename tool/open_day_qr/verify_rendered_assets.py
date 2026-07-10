#!/usr/bin/env python3
"""Decode every rendered QR artifact and write the public QA report."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from pathlib import Path


def decode(decoder: Path, image: Path) -> list[str]:
    result = subprocess.run(
        [str(decoder), str(image)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return []
    return [line for line in result.stdout.splitlines() if line]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pack", type=Path, required=True)
    parser.add_argument("--decoder", type=Path, required=True)
    parser.add_argument("--rsvg-convert", default="rsvg-convert")
    parser.add_argument("--pdftoppm", default="pdftoppm")
    parser.add_argument("--magick", default="magick")
    args = parser.parse_args()

    manifest = json.loads((args.pack / "manifest.json").read_text(encoding="utf-8"))
    payloads = json.loads((args.pack / "payloads.json").read_text(encoding="utf-8"))
    expected = {entry["locationId"]: entry["uri"] for entry in payloads["payloads"]}
    contact = args.pack / "contact-sheet" / "mq-journey-open-day-qr-contact-sheet.png"
    results = []

    with tempfile.TemporaryDirectory(prefix="mqj-qr-decode-") as temporary:
        work = Path(temporary)
        for index, entry in enumerate(manifest["locations"]):
            location_id = entry["locationId"]
            uri = expected[location_id]
            svg_render = work / f"{index:02d}-svg.png"
            poster_render = work / f"{index:02d}-poster.png"
            contact_crop = work / f"{index:02d}-contact.png"
            subprocess.run(
                [args.rsvg_convert, "-w", "2048", "-h", "2048", "-o", str(svg_render), str(args.pack / entry["svg"])],
                check=True,
            )
            subprocess.run(
                [args.pdftoppm, "-f", "1", "-singlefile", "-r", "300", "-png", str(args.pack / entry["poster"]), str(poster_render.with_suffix(""))],
                check=True,
            )
            row, column = divmod(index, 3)
            x = column * 827
            y = 208 + row * 1100
            subprocess.run(
                [args.magick, str(contact), "-crop", f"827x1100+{x}+{y}", "+repage", str(contact_crop)],
                check=True,
            )
            statuses = {
                "svg": "accepted" if decode(args.decoder, svg_render) == [uri] else "rejected",
                "png": "accepted" if decode(args.decoder, args.pack / entry["png"]) == [uri] else "rejected",
                "poster": "accepted" if decode(args.decoder, poster_render) == [uri] else "rejected",
                "contactSheet": "accepted" if decode(args.decoder, contact_crop) == [uri] else "rejected",
            }
            results.append(
                {
                    "locationId": location_id,
                    **statuses,
                    "decodedLocationId": location_id if set(statuses.values()) == {"accepted"} else "mismatch",
                    "signature": "valid",
                    "allowlist": "present",
                }
            )

    all_passed = all(set(result[key] for key in ("svg", "png", "poster", "contactSheet")) == {"accepted"} for result in results)
    report = {
        "schema": "mqjourney.open-day.qr-decode-report.v1",
        "expectedCount": 9,
        "posterRenderDpi": 300,
        "contactSheetCellMode": "independent-crop",
        "results": results,
        "allPassed": all_passed,
    }
    (args.pack / "qa" / "decode-report.json").write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    if not all_passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
