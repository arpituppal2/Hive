#!/usr/bin/env python3
"""Generate Hive Browser app icon — hexagon with warm indigo/gold gradient."""

import math
import os
from PIL import Image, ImageDraw

# Output dir: Sources/HiveChromium/Resources/Icon.iconset/
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
    "..", "Sources", "HiveChromium", "Resources", "Icon.iconset")
os.makedirs(OUT_DIR, exist_ok=True)

# Brand palette
INDIGO = (99, 102, 241)    # #6366F1
GOLD = (245, 158, 11)      # #F59E0B
DEEP_INDIGO = (79, 70, 229) # darker for depth

def hexagon_vertices(cx, cy, r):
    """Return 6 vertices of a flat-top hexagon centered at (cx,cy)."""
    verts = []
    for i in range(6):
        angle = math.pi / 3 * i - math.pi / 6  # flat-top orientation
        x = cx + r * math.cos(angle)
        y = cy + r * math.sin(angle)
        verts.append((x, y))
    return verts

def rounded_hexagon_vertices(cx, cy, r, corner_r=0.12):
    """Return vertices with chamfered/rounded corners for a softer hexagon."""
    verts = hexagon_vertices(cx, cy, r * (1.0 - corner_r * 0.5))
    return verts

def draw_icon(size):
    """Draw a single icon at the given size (e.g. 512x512) and return PIL Image."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    margin = size * 0.08
    r = (size / 2) - margin
    cx, cy = size / 2, size / 2

    verts = hexagon_vertices(cx, cy, r)

    # Gradient fill: top-left indigo to bottom-right gold
    for y in range(size):
        for x in range(size):
            # Check if inside hexagon using winding number
            if not point_in_polygon(x, y, verts):
                continue
            # Gradient interpolation: top-left = indigo, bottom-right = gold
            t = (x / size + y / size) / 2.0  # 0 (top-left) to 1 (bottom-right)
            t = max(0.0, min(1.0, t))
            r_val = int(INDIGO[0] + (GOLD[0] - INDIGO[0]) * t)
            g_val = int(INDIGO[1] + (GOLD[1] - INDIGO[1]) * t)
            b_val = int(INDIGO[2] + (GOLD[2] - INDIGO[2]) * t)
            img.putpixel((x, y), (r_val, g_val, b_val, 255))

    # Subtle inner highlight (top-left lighter)
    for y in range(int(size * 0.1), int(size * 0.35)):
        for x in range(int(size * 0.1), int(size * 0.35)):
            if not point_in_polygon(x, y, verts):
                continue
            t = 1.0 - ( (x - size * 0.1) / (size * 0.25) + (y - size * 0.1) / (size * 0.25) ) / 2.0
            t = max(0.0, min(0.3, t))
            r_val, g_val, b_val, a = img.getpixel((x, y))
            highlight = int(255 * t)
            img.putpixel((x, y), (
                min(255, r_val + highlight),
                min(255, g_val + highlight),
                min(255, b_val + highlight),
                255))

    # Hexagon border: 2px subtle stroke
    border_r = r - 1
    border_verts = hexagon_vertices(cx, cy, border_r)
    for i in range(6):
        x1, y1 = border_verts[i]
        x2, y2 = border_verts[(i + 1) % 6]
        draw_line(draw, x1, y1, x2, y2, (255, 255, 255, 45))

    # Outer border
    outer_r = r + 1
    outer_verts = hexagon_vertices(cx, cy, outer_r)
    for i in range(6):
        x1, y1 = outer_verts[i]
        x2, y2 = outer_verts[(i + 1) % 6]
        draw_line(draw, x1, y1, x2, y2, (255, 255, 255, 30))

    # Simple "H" letterform at center for recognizability at small sizes
    if size >= 32:
        h_size = size * 0.08
        h_x, h_y = cx, cy
        # Vertical bars of H
        bar_w = int(size * 0.04)
        bar_h = int(size * 0.22)
        # Left bar
        draw.rectangle([
            h_x - int(size * 0.085), h_y - bar_h // 2,
            h_x - int(size * 0.085) + bar_w, h_y + bar_h // 2
        ], fill=(255, 255, 255, 200))
        # Right bar
        draw.rectangle([
            h_x + int(size * 0.085) - bar_w, h_y - bar_h // 2,
            h_x + int(size * 0.085), h_y + bar_h // 2
        ], fill=(255, 255, 255, 200))
        # Cross bar
        cross_h = int(size * 0.04)
        draw.rectangle([
            h_x - int(size * 0.085), h_y - cross_h // 2,
            h_x + int(size * 0.085), h_y + cross_h // 2
        ], fill=(255, 255, 255, 200))

    return img

def point_in_polygon(x, y, verts):
    """Ray casting algorithm."""
    n = len(verts)
    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = verts[i]
        xj, yj = verts[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
            inside = not inside
        j = i
    return inside

def draw_line(draw, x1, y1, x2, y2, color):
    """Bresenham-like line drawing using small rectangles for anti-aliased edges."""
    # Simple approach: use PIL's line
    draw.line([(x1, y1), (x2, y2)], fill=color, width=1)

# macOS required icon sizes
SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}

if __name__ == "__main__":
    # Generate base 1024x1024 image once, then resize
    print("Generating base 1024x1024 icon...")
    base = draw_icon(1024)

    for filename, size in SIZES.items():
        path = os.path.join(OUT_DIR, filename)
        if size == 1024:
            base.save(path, "PNG")
        else:
            resized = base.resize((size, size), Image.LANCZOS)
            resized.save(path, "PNG")
        print(f"  {filename} ({size}x{size})")

    print(f"\nIcons written to {OUT_DIR}")
    print("Run: iconutil -c icns Icon.iconset -o HiveBrowser.icns")
