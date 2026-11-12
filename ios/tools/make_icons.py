#!/usr/bin/env python3
"""Noor Glass app icons: a gold mosque silhouette (central dome, two
minarets) and a crescent over the theme's primary gradient, with a
soft top gloss. Drawn entirely with PIL shapes (no text), rendered
at 2x and downscaled for clean edges.

One icon family per theme preset (phase 2 full theming): the
default AppIcon uses the Mosque Green preset; the alternates
(AppIconOcean, AppIconDesert, ...) are registered in Info.plist
under CFBundleAlternateIcons and offered in Settings > Appearance.
IconPreview*.imageset holds 180pt previews for the in-app picker.

Run from ios/:  python3 tools/make_icons.py
"""
import colorsys
import json
import os

from PIL import Image, ImageDraw, ImageFilter

S = 2  # supersample factor
W = 1024 * S
HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "NoorGlass", "Assets.xcassets")


def hex2rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def lighten(rgb, amount):
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
    l = min(1.0, l + (1.0 - l) * amount)
    return tuple(round(c * 255) for c in colorsys.hls_to_rgb(h, l, s))


def darken(rgb, amount):
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
    l = max(0.0, l * (1.0 - amount))
    return tuple(round(c * 255) for c in colorsys.hls_to_rgb(h, l, s))


def vertical_gradient(top, mid, bottom):
    img = Image.new("RGB", (W, W))
    draw = ImageDraw.Draw(img)
    for row in range(W):
        t = row / W
        if t < 0.5:
            k = t / 0.5
            c = tuple(int(top[i] + (mid[i] - top[i]) * k) for i in range(3))
        else:
            k = (t - 0.5) / 0.5
            c = tuple(int(mid[i] + (bottom[i] - mid[i]) * k) for i in range(3))
        draw.line([(0, row), (W, row)], fill=c)
    return img


def silhouette_mask():
    """The mosque + crescent artwork as an L mask."""
    mask = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(mask)
    u = W / 1024.0  # unit
    base_y = 800 * u
    # Building base
    d.rectangle([272 * u, 640 * u, 752 * u, base_y], fill=255)
    # Central dome: half-ellipse body + finial
    d.pieslice([352 * u, 380 * u, 672 * u, 700 * u], 180, 360, fill=255)
    d.rectangle([352 * u, 540 * u, 672 * u, 660 * u], fill=255)
    d.rectangle([504 * u, 300 * u, 520 * u, 400 * u], fill=255)
    d.ellipse([488 * u, 268 * u, 536 * u, 316 * u], fill=255)
    # Side domes, sitting on the building base
    for cx in (300, 724):
        d.pieslice([(cx - 66) * u, 560 * u, (cx + 66) * u, 692 * u], 180, 360, fill=255)
    # Minarets
    for cx in (196, 828):
        d.rectangle([(cx - 22) * u, 380 * u, (cx + 22) * u, base_y], fill=255)
        d.rectangle([(cx - 40) * u, 470 * u, (cx + 40) * u, 500 * u], fill=255)
        d.pieslice([(cx - 34) * u, 300 * u, (cx + 34) * u, 420 * u], 180, 360, fill=255)
        d.rectangle([(cx - 4) * u, 258 * u, (cx + 4) * u, 330 * u], fill=255)
    # Ground
    d.rectangle([140 * u, base_y, 884 * u, base_y + 14 * u], fill=255)
    # Crescent, top right
    cx, cy, r = 800 * u, 190 * u, 74 * u
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    cut = Image.new("L", (W, W), 0)
    dc = ImageDraw.Draw(cut)
    dc.ellipse([cx - r * 0.82 + 34 * u, cy - r * 0.82 - 14 * u,
                cx + r * 0.82 + 34 * u, cy + r * 0.82 - 14 * u], fill=255)
    mask = Image.composite(Image.new("L", (W, W), 0), mask, cut)
    return mask


def render(primary_hex, accent_hex):
    primary = hex2rgb(primary_hex)
    accent = hex2rgb(accent_hex)
    img = vertical_gradient(lighten(primary, 0.22), primary, darken(primary, 0.5))
    # Silhouette filled with an accent gradient
    grad = vertical_gradient(lighten(accent, 0.35), accent, darken(accent, 0.35))
    mask = silhouette_mask()
    img.paste(grad, (0, 0), mask)
    # Soft top gloss
    gloss = Image.new("L", (W, W), 0)
    dg = ImageDraw.Draw(gloss)
    dg.ellipse([-W * 0.25, -W * 0.62, W * 1.25, W * 0.28], fill=70)
    gloss = gloss.filter(ImageFilter.GaussianBlur(W * 0.03))
    white = Image.new("RGB", (W, W), (255, 255, 255))
    img.paste(white, (0, 0), gloss)
    return img.resize((1024, 1024), Image.LANCZOS)


# icon name -> (preview name, primary, accent); matches NoorAppearance presets
FAMILIES = [
    ("AppIcon", "Default", "0B3D2E", "D4AF37"),
    ("AppIconOcean", "Ocean", "083344", "67E8F9"),
    ("AppIconDesert", "Desert", "6B4420", "F2C14E"),
    ("AppIconEmerald", "Emerald", "052E22", "34D399"),
    ("AppIconCrimson", "Crimson", "450A0A", "FCA5A5"),
    ("AppIconSapphire", "Sapphire", "172554", "93C5FD"),
    ("AppIconPlum", "Plum", "3B0764", "F0ABFC"),
    ("AppIconContrast", "Contrast", "000000", "FFD60A"),
]

ICONSET_JSON = {
    "images": [
        {"filename": "icon-1024.png", "idiom": "iphone", "scale": "1x", "size": "1024x1024"},
        {"filename": "icon-1024.png", "idiom": "ipad", "scale": "1x", "size": "1024x1024"},
        {"filename": "icon-1024.png", "idiom": "ios-marketing", "scale": "1x", "size": "1024x1024"},
    ],
    "info": {"author": "xcode", "version": 1},
}


def write_json(path, data):
    with open(path, "w") as fh:
        json.dump(data, fh, indent=1)


def main():
    mask = None  # mask built per render (cheap enough)
    for icon_name, preview_name, primary, accent in FAMILIES:
        img = render(primary, accent)
        iconset = os.path.join(ASSETS, f"{icon_name}.appiconset")
        os.makedirs(iconset, exist_ok=True)
        img.save(os.path.join(iconset, "icon-1024.png"))
        write_json(os.path.join(iconset, "Contents.json"), ICONSET_JSON)
        previews = os.path.join(ASSETS, f"IconPreview{preview_name}.imageset")
        os.makedirs(previews, exist_ok=True)
        images = []
        for scale, px in ((1, 180), (2, 360), (3, 540)):
            name = f"preview-{px}.png" if scale == 1 else f"preview-{px}@{scale}x.png"
            img.resize((px, px), Image.LANCZOS).save(os.path.join(previews, name))
            images.append({"filename": name, "idiom": "universal",
                           "scale": f"{scale}x"})
        write_json(os.path.join(previews, "Contents.json"),
                   {"images": images, "info": {"author": "xcode", "version": 1}})
        print("wrote", icon_name)


if __name__ == "__main__":
    main()
