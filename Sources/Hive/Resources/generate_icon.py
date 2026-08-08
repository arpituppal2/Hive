"""Generate Hive app icon .icns from brand colors."""
from PIL import Image, ImageDraw
import math, os, subprocess

out_dir = os.path.join(os.path.dirname(__file__), "AppIcon.iconset")
os.makedirs(out_dir, exist_ok=True)

INDIGO = (99, 102, 241)
GOLD = (245, 158, 11)
DARK = (8, 9, 10)
WHITE = (255, 255, 255)

def draw_hexagon(draw, cx, cy, r, outline_color=GOLD, outline_width=0):
    """Draw a flat-top hexagon centered at (cx, cy) with radius r."""
    pts = [
        (cx + r * math.cos(2 * math.pi * i / 6 - math.pi / 6),
         cy + r * math.sin(2 * math.pi * i / 6 - math.pi / 6))
        for i in range(6)
    ]
    draw.polygon(pts, fill=DARK)
    if outline_width > 0:
        draw.polygon(pts, outline=outline_color, width=outline_width)
    return pts

def draw_h(draw, cx, cy, r, color=GOLD):
    """Draw a bold 'H' centered in the hexagon."""
    hw = r * 0.4  # half width of H
    hh = r * 0.5  # half height
    bar = r * 0.18  # bar thickness
    # Left vertical
    draw.rectangle([cx - hw, cy - hh, cx - hw + bar, cy + hh], fill=color)
    # Right vertical
    draw.rectangle([cx + hw - bar, cy - hh, cx + hw, cy + hh], fill=color)
    # Crossbar
    draw.rectangle([cx - hw, cy - bar/2, cx + hw, cy + bar/2], fill=color)

def make_icon(size: int):
    """Create a single icon image at the given pixel size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Gradient background: indigo top to gold bottom
    for y in range(size):
        ratio = y / size
        r = int(INDIGO[0] + (GOLD[0] - INDIGO[0]) * ratio)
        g = int(INDIGO[1] + (GOLD[1] - INDIGO[1]) * ratio)
        b_chan = int(INDIGO[2] + (GOLD[2] - INDIGO[2]) * ratio)
        d.rectangle([0, y, size, y + 1], fill=(r, g, b_chan))

    cx, cy = size // 2, size // 2
    hex_r = int(size * 0.38)
    outline_w = max(2, int(hex_r * 0.06))
    draw_hexagon(d, cx, cy, hex_r, GOLD, outline_w)
    draw_h(d, cx, cy, hex_r, GOLD)

    return img

def save_size_pair(base_size, scale2x):
    """Save icon at base_size and optional @2x."""
    if scale2x:
        img = make_icon(base_size * 2)
        name = f"icon_{base_size}x{base_size}@2x.png"
    else:
        img = make_icon(base_size)
        name = f"icon_{base_size}x{base_size}.png"
    img.save(os.path.join(out_dir, name))
    print(f"  {name} ({img.size[0]}x{img.size[1]})")

# Standard macOS icon sizes
print("Generating icons...")
save_size_pair(16, False)   # 16x16
save_size_pair(16, True)    # 32x32
save_size_pair(32, False)   # 32x32
save_size_pair(32, True)    # 64x64
save_size_pair(128, False)  # 128x128
save_size_pair(128, True)   # 256x256
save_size_pair(256, False)  # 256x256
save_size_pair(256, True)   # 512x512
save_size_pair(512, False)  # 512x512
save_size_pair(512, True)   # 1024x1024

print("Running iconutil...")
icns_path = os.path.join(os.path.dirname(__file__), "AppIcon.icns")
result = subprocess.run(
    ["iconutil", "-c", "icns", out_dir, "-o", icns_path],
    capture_output=True, text=True
)
if result.returncode == 0:
    print(f"✅ AppIcon.icns created ({os.path.getsize(icns_path)} bytes)")
else:
    print(f"❌ iconutil failed: {result.stderr}")
