#!/usr/bin/env python3
"""Derive every app-icon / splash artifact from the canonical artwork.

Source of truth: assets/images/app_logo.png — a rounded beige tile on a
transparent canvas. That transparency is what produced the "white circle":
iOS icon generation flattened it onto white, and Android (no adaptive icon)
put the legacy PNG on a white launcher/splash backplate.

Outputs (no artwork is redrawn — only cropped, re-matted and resized):
  assets/images/app_icon_full_bleed.png  1024² opaque square for iOS/legacy
  assets/images/app_icon_foreground.png  1024² adaptive-icon foreground
  assets/images/app_icon_tile.png        tight rounded tile for splash screens
  + native splash PNGs for iOS LaunchImage and Android (pre-12 and 12+)

Run: python3 tool/branding/build_icon_assets.py
"""
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'assets/images/app_logo.png'

src = Image.open(SRC).convert('RGBA')
bbox = src.split()[3].point(lambda v: 255 if v > 250 else 0).getbbox()
tile = src.crop(bbox)  # rounded tile, transparent corners, white edge rim
N = tile.size[0]

# Least-squares plane through the tile background (a sample band just inside
# the rim, away from the artwork) so the soft diagonal gradient is reproduced.
samples = []
for i in range(12, N - 12, 8):
    for (x, y) in ((i, 12), (12, i), (i, N - 13), (N - 13, i)):
        r, g, b, a = tile.getpixel((x, y))
        if a == 255:
            samples.append((x / N, y / N, r, g, b))
def fit(ch):
    import itertools
    sx = sum(s[0] for s in samples); sy = sum(s[1] for s in samples)
    n = len(samples)
    sxx = sum(s[0] ** 2 for s in samples); syy = sum(s[1] ** 2 for s in samples)
    sxy = sum(s[0] * s[1] for s in samples)
    sv = sum(s[ch] for s in samples)
    sxv = sum(s[0] * s[ch] for s in samples); syv = sum(s[1] * s[ch] for s in samples)
    # Solve [n sx sy; sx sxx sxy; sy sxy syy] [a b c] = [sv sxv syv]
    m = [[n, sx, sy, sv], [sx, sxx, sxy, sxv], [sy, sxy, syy, syv]]
    for c in range(3):
        p = max(range(c, 3), key=lambda r: abs(m[r][c])); m[c], m[p] = m[p], m[c]
        for r in range(3):
            if r != c:
                f = m[r][c] / m[c][c]
                m[r] = [m[r][k] - f * m[c][k] for k in range(4)]
    return [m[i][3] / m[i][i] for i in range(3)]
planes = [fit(2), fit(3), fit(4)]
def bg_at(u, v):
    return tuple(max(0, min(255, round(p[0] + p[1] * u + p[2] * v))) for p in planes)

# 1. Full-bleed opaque master: trim the 4px rim, fill the rounded corners with
#    the background plane. iOS applies its own (larger-radius) mask.
inset = 6
core = tile.crop((inset, inset, N - inset, N - inset))
M = core.size[0]
plate = Image.new('RGBA', (M, M))
pp = plate.load()
for y in range(M):
    for x in range(M):
        pp[x, y] = bg_at((x + inset) / N, (y + inset) / N) + (255,)
full = Image.alpha_composite(plate, core).convert('RGB').resize((1024, 1024), Image.LANCZOS)
full.save(ROOT / 'assets/images/app_icon_full_bleed.png')

# 2. Adaptive foreground: un-composite the artwork from the known background
#    (alpha from colour distance), then fit it inside the 66/108 safe zone.
art = Image.new('RGBA', (M, M))
ap = art.load(); cp = core.load()
# Only matte the tile's interior: shrink its alpha past the white edge rim
# (which follows the rounded corners) so the rim never becomes "artwork".
from PIL import ImageFilter
interior = tile.split()[3].filter(ImageFilter.MinFilter(25)).crop(
    (inset, inset, N - inset, N - inset)).load()
for y in range(M):
    for x in range(M):
        r, g, b, a = cp[x, y]
        br, bgc, bb = bg_at((x + inset) / N, (y + inset) / N)
        d = max(abs(r - br), abs(g - bgc), abs(b - bb))
        al = min(1.0, d / 40.0) * (a / 255) * (interior[x, y] / 255)
        if al <= 0.02:
            ap[x, y] = (0, 0, 0, 0); continue
        un = [max(0, min(255, round((c - (1 - al) * k) / al))) for c, k in ((r, br), (g, bgc), (b, bb))]
        ap[x, y] = tuple(un) + (round(al * 255),)
art_bbox = art.split()[3].point(lambda v: 255 if v > 24 else 0).getbbox()
art = art.crop(art_bbox)
canvas = 1024
safe = canvas * 66 / 108 * 0.92   # a little breathing room inside the safe zone
scale = safe / max(art.size)
art = art.resize((round(art.size[0] * scale), round(art.size[1] * scale)), Image.LANCZOS)
fg = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
fg.alpha_composite(art, ((canvas - art.size[0]) // 2, (canvas - art.size[1]) // 2))
fg.save(ROOT / 'assets/images/app_icon_foreground.png')
mid = bg_at(0.5, 0.5)
(ROOT / 'tool/branding/adaptive_background.txt').write_text('#%02X%02X%02X\n' % mid)

# 3. Splash tile: the canonical rounded tile itself (natural presentation).
tile.resize((672, 672), Image.LANCZOS).save(ROOT / 'assets/images/app_icon_tile.png')

# 4. Native splash images at 112pt / 112dp, matching the Flutter splash.
ios = ROOT / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
for suffix, px in (('', 112), ('@2x', 224), ('@3x', 336)):
    tile.resize((px, px), Image.LANCZOS).save(ios / f'LaunchImage{suffix}.png')
res = ROOT / 'android/app/src/main/res'
for bucket, f in (('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)):
    d = res / f'drawable-{bucket}'; d.mkdir(exist_ok=True)
    tile.resize((round(112 * f),) * 2, Image.LANCZOS).save(d / 'launch_icon.png')
    # Android 12+: 240dp icon canvas, masked to a 160dp circle. A 112dp tile
    # (diagonal 158dp) fits inside that circle untouched.
    c = round(240 * f); t = round(112 * f)
    s12 = Image.new('RGBA', (c, c), (0, 0, 0, 0))
    s12.alpha_composite(tile.resize((t, t), Image.LANCZOS), ((c - t) // 2, (c - t) // 2))
    s12.save(d / 'splash_icon_android12.png')
print('adaptive background', '#%02X%02X%02X' % mid, 'art scale', round(scale, 3))
