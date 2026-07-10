#!/usr/bin/env python3
"""Build public Open Day print assets from signed SVG masters."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

from reportlab.lib.colors import HexColor, black, white
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas


EXPECTED = (
    (1, "hadenfeld-10", "10 Hadenfeld Avenue", "P6"),
    (2, "wallys-29", "29 Wally's Walk", "L11"),
    (3, "wallys-27", "27 Wally's Walk", "L12"),
    (4, "wallys-23", "23 Wally's Walk", "L14"),
    (5, "wallys-21", "21 Wally's Walk", "L15"),
    (6, "wallys-17", "17 Wally's Walk", "L17"),
    (7, "ondaatje-14", "14 Sir Christopher Ondaatje Avenue", "J20"),
    (8, "wallys-1", "1 Wally's Walk", "K27"),
    (9, "wallys-25", "25 Wally's Walk", "N12"),
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: object) -> None:
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def validate_sources(source: Path, trail_path: Path, stamps_path: Path, key_id: str) -> dict:
    manifest = load_json(source / "manifest.json")
    trail = load_json(trail_path)["locations"]
    stamps = load_json(stamps_path)["stamps"]
    if manifest.get("keyId") != key_id or manifest.get("count") != 9:
        raise ValueError("signed master manifest does not use the selected nine-code key")
    actual = []
    for index, expected in enumerate(EXPECTED):
        ordinal, location_id, title, map_ref = expected
        trail_entry = trail[index]
        stamp_entry = stamps[index]
        manifest_entry = manifest["locations"][index]
        actual.append(
            (
                ordinal,
                trail_entry.get("locationId"),
                trail_entry.get("title"),
                stamp_entry.get("mapRef"),
            )
        )
        if stamp_entry.get("locationId") != location_id:
            raise ValueError(f"stamp census mismatch for {location_id}")
        if manifest_entry.get("locationId") != location_id:
            raise ValueError(f"signed master mismatch for {location_id}")
        if not (source / manifest_entry["file"]).is_file():
            raise ValueError(f"missing SVG master for {location_id}")
    if tuple(actual) != EXPECTED:
        raise ValueError("trail/stamp census differs from the production contract")
    return manifest


def svg_geometry(path: Path) -> tuple[float, list[tuple[float, float, float, float]]]:
    root = ET.fromstring(path.read_text(encoding="utf-8"))
    view_box = root.attrib.get("viewBox", "").split()
    if len(view_box) != 4 or view_box[:2] != ["0", "0"]:
        raise ValueError(f"unsupported SVG viewBox in {path.name}")
    size = float(view_box[2])
    rectangles = []
    for element in root.iter():
        if element.tag.rsplit("}", 1)[-1] != "rect" or "x" not in element.attrib:
            continue
        rectangles.append(
            tuple(float(element.attrib[name]) for name in ("x", "y", "width", "height"))
        )
    if not rectangles:
        raise ValueError(f"no QR modules in {path.name}")
    return size, rectangles


def draw_svg_qr(page: canvas.Canvas, path: Path, x: float, y: float, size: float) -> None:
    source_size, rectangles = svg_geometry(path)
    scale = size / source_size
    page.setFillColor(white)
    page.rect(x, y, size, size, stroke=0, fill=1)
    page.setFillColor(black)
    for module_x, module_y, width, height in rectangles:
        page.rect(
            x + module_x * scale,
            y + (source_size - module_y - height) * scale,
            width * scale,
            height * scale,
            stroke=0,
            fill=1,
        )


def create_poster(path: Path, svg: Path, title: str, map_ref: str, location_id: str) -> None:
    width, height = A4
    page = canvas.Canvas(str(path), pagesize=A4, pageCompression=1, invariant=1)
    page.setTitle(f"MQ Journey Open Day QR - {title}")
    page.setFillColor(HexColor("#A6192E"))
    page.rect(0, height - 74, width, 74, stroke=0, fill=1)
    page.setFillColor(white)
    page.setFont("Helvetica-Bold", 24)
    page.drawCentredString(width / 2, height - 46, "MQ JOURNEY · OPEN DAY")
    page.setFillColor(black)
    title_size = 25 if len(title) < 28 else 20
    page.setFont("Helvetica-Bold", title_size)
    page.drawCentredString(width / 2, height - 125, title)
    page.setFont("Helvetica", 15)
    page.drawCentredString(width / 2, height - 151, f"Campus map reference: {map_ref}")
    qr_size = 420
    draw_svg_qr(page, svg, (width - qr_size) / 2, 210, qr_size)
    page.setFont("Helvetica-Bold", 22)
    page.drawCentredString(width / 2, 169, "Scan with MQ Journey")
    page.setFont("Helvetica", 14)
    page.drawCentredString(
        width / 2,
        143,
        "Discover this location and collect its stamp.",
    )
    page.setFont("Helvetica", 9)
    page.setFillColor(HexColor("#555555"))
    page.drawCentredString(width / 2, 94, f"Installation ID: {location_id}")
    page.drawCentredString(
        width / 2,
        73,
        "MQ Journey is an independent student navigation project.",
    )
    page.showPage()
    page.save()


def create_contact_sheet(path: Path, entries: list[dict]) -> None:
    width, height = A4
    page = canvas.Canvas(str(path), pagesize=A4, pageCompression=1, invariant=1)
    page.setTitle("MQ Journey Open Day QR verification contact sheet")
    page.setFillColor(HexColor("#A6192E"))
    page.rect(0, height - 50, width, 50, stroke=0, fill=1)
    page.setFillColor(white)
    page.setFont("Helvetica-Bold", 18)
    page.drawCentredString(width / 2, height - 32, "MQ JOURNEY · QR VERIFICATION SHEET")
    cell_width = width / 3
    cell_height = (height - 50) / 3
    qr_size = 130
    for index, entry in enumerate(entries):
        row, column = divmod(index, 3)
        left = column * cell_width
        top = height - 50 - row * cell_height
        page.setStrokeColor(HexColor("#D0D0D0"))
        page.rect(left, top - cell_height, cell_width, cell_height, stroke=1, fill=0)
        page.setFillColor(black)
        page.setFont("Helvetica-Bold", 10)
        title = entry["title"]
        if len(title) > 29:
            title = title[:28] + "…"
        page.drawCentredString(left + cell_width / 2, top - 22, f"{entry['ordinal']}. {title}")
        page.setFont("Helvetica", 9)
        page.drawCentredString(left + cell_width / 2, top - 37, f"Map {entry['mapRef']}")
        draw_svg_qr(
            page,
            Path(entry["sourceSvg"]),
            left + (cell_width - qr_size) / 2,
            top - 46 - qr_size,
            qr_size,
        )
        page.setFont("Helvetica", 8)
        page.drawCentredString(left + cell_width / 2, top - 190, entry["locationId"])
    page.showPage()
    page.save()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--trail", type=Path, required=True)
    parser.add_argument("--stamps", type=Path, required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--rsvg-convert", default="rsvg-convert")
    parser.add_argument("--pdftoppm", default="pdftoppm")
    args = parser.parse_args()

    source_manifest = validate_sources(
        args.source,
        args.trail,
        args.stamps,
        args.key_id,
    )
    if args.out.exists():
        shutil.rmtree(args.out)
    for directory in (
        "qr-svg",
        "qr-png",
        "posters-pdf",
        "contact-sheet",
        "qa",
    ):
        (args.out / directory).mkdir(parents=True, exist_ok=True)

    payloads = []
    entries = []
    for index, expected in enumerate(EXPECTED):
        ordinal, location_id, title, map_ref = expected
        base = f"{ordinal:02d}-{location_id}"
        source_entry = source_manifest["locations"][index]
        source_svg = args.source / source_entry["file"]
        svg = args.out / "qr-svg" / f"{base}.svg"
        png = args.out / "qr-png" / f"{base}.png"
        poster = args.out / "posters-pdf" / f"{base}.pdf"
        shutil.copyfile(source_svg, svg)
        subprocess.run(
            [args.rsvg_convert, "-w", "2048", "-h", "2048", "-o", str(png), str(svg)],
            check=True,
        )
        create_poster(poster, svg, title, map_ref, location_id)
        uri = source_entry["uri"]
        source_size, _ = svg_geometry(svg)
        module_count = int(source_size) - 8
        entries.append(
            {
                "ordinal": ordinal,
                "locationId": location_id,
                "title": title,
                "mapRef": map_ref,
                "svg": f"qr-svg/{base}.svg",
                "png": f"qr-png/{base}.png",
                "poster": f"posters-pdf/{base}.pdf",
                "payloadSha256": sha256_bytes(uri.encode("utf-8")),
                "svgSha256": sha256_file(svg),
                "pngSha256": sha256_file(png),
                "posterSha256": sha256_file(poster),
                "moduleCount": module_count,
                "qrVersion": (module_count - 17) // 4,
                "sourceSvg": str(svg),
            }
        )
        payloads.append({"locationId": location_id, "uri": uri})

    contact_pdf = args.out / "contact-sheet" / "mq-journey-open-day-qr-contact-sheet.pdf"
    create_contact_sheet(contact_pdf, entries)
    contact_prefix = args.out / "contact-sheet" / "mq-journey-open-day-qr-contact-sheet"
    subprocess.run(
        [args.pdftoppm, "-f", "1", "-singlefile", "-r", "300", "-png", str(contact_pdf), str(contact_prefix)],
        check=True,
    )
    for entry in entries:
        entry.pop("sourceSvg")

    write_json(
        args.out / "manifest.json",
        {
            "schema": "mqjourney.open-day.qr-production-pack.v1",
            "keyId": args.key_id,
            "count": len(entries),
            "sourceTrail": str(args.trail),
            "sourceStampCatalogue": str(args.stamps),
            "locations": entries,
        },
    )
    write_json(
        args.out / "payloads.json",
        {
            "schema": "mqjourney.open-day.qr-payloads.v1",
            "keyId": args.key_id,
            "payloads": payloads,
        },
    )
    (args.out / "README.txt").write_text(
        "MQ Journey Open Day QR production pack (2026)\n"
        f"Signing key ID: {args.key_id}\n"
        "All QR files are public signed payloads. No private key material is included.\n"
        "Verify from this directory with: shasum -a 256 -c SHA256SUMS\n"
        "The ZIP SHA-256 is published alongside the release archive.\n",
        encoding="utf-8",
        newline="\n",
    )


if __name__ == "__main__":
    main()
