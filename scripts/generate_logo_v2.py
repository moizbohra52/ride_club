#!/usr/bin/env python3
"""
RideClub — Professional Logo v2
================================
Full-bleed circular logo with no white space. Professional gradient background
with a modern cyclist silhouette, map pin, and speed lines.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "images")

ANDROID = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}
WEB = {
    "Icon-192.png":            192,
    "Icon-512.png":            512,
    "Icon-maskable-192.png":   192,
    "Icon-maskable-512.png":   512,
}
IOS = {
    "Icon-20@2x.png":          40,
    "Icon-20@3x.png":          60,
    "Icon-29@2x.png":          58,
    "Icon-29@3x.png":          87,
    "Icon-40@2x.png":          80,
    "Icon-40@3x.png":         120,
    "Icon-60@2x.png":         120,
    "Icon-60@3x.png":         180,
    "Icon-20.png":             20,
    "Icon-29.png":             29,
    "Icon-40.png":             40,
    "Icon-76.png":             76,
    "Icon-76@2x.png":         152,
    "Icon-83.5@2x.png":       167,
    "Icon-1024.png":         1024,
}
LOGO_SIZE = 1024


def generate_logo(size):
    """Generate a full-bleed professional logo - no white space, fills entire circle."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx, cy = size // 2, size // 2
    r = size * 0.48  # Almost full circle

    # ── 1. Background gradient (sunset-to-midnight) ──
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    steps = 80
    for i in range(steps, 0, -1):
        t = i / steps
        rad = r * t
        # Deep purple-blue to vibrant orange-red gradient
        r_col = int(180 - 80 * (1 - t))
        g_col = int(40 + 60 * (1 - t))
        b_col = int(180 - 100 * (1 - t))
        bg_draw.ellipse(
            (cx - rad, cy - rad, cx + rad, cy + rad),
            fill=(r_col, g_col, b_col, 255),
        )

    # Add a second gradient layer for depth (warm glow from bottom-right)
    for i in range(steps, 0, -1):
        t = i / steps
        rad = r * t * 0.85
        r_col = int(255 - 50 * t)
        g_col = int(100 - 60 * t)
        b_col = int(50 - 30 * t)
        bg_draw.ellipse(
            (cx - rad + size*0.1, cy - rad + size*0.1,
             cx + rad + size*0.1, cy + rad + size*0.1),
            fill=(r_col, g_col, b_col, 60),
        )

    bg = bg.filter(ImageFilter.GaussianBlur(radius=size * 0.03))
    img = Image.alpha_composite(img, bg)

    # ── 2. Outer ring ──
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ring_draw = ImageDraw.Draw(ring)
    ring_w = size * 0.025
    ring_draw.ellipse(
        (cx - r + ring_w, cy - r + ring_w, cx + r - ring_w, cy + r - ring_w),
        outline=(255, 220, 100, 180),
        width=max(3, int(ring_w * 2)),
    )
    img = Image.alpha_composite(img, ring)

    # ── 3. Inner glow ring ──
    inner_r = r * 0.88
    ring_draw.ellipse(
        (cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r),
        outline=(255, 255, 255, 30),
        width=max(1, int(size * 0.01)),
    )

    # ── 4. Stylized cyclist ──
    s = size / 512
    rd = ImageDraw.Draw(img)

    # Head
    head_r = 28 * s
    head_cx, head_cy = cx + 15 * s, cy - 70 * s
    rd.ellipse(
        (head_cx - head_r, head_cy - head_r, head_cx + head_r, head_cy + head_r),
        fill=(255, 255, 255, 240),
    )

    # Helmet
    rd.arc(
        (head_cx - head_r * 1.2, head_cy - head_r * 1.4,
         head_cx + head_r * 1.2, head_cy + head_r * 0.2),
        start=190, end=350,
        fill=(255, 215, 0, 220),
        width=max(3, int(7 * s)),
    )

    # Torso (leaning forward aggressively - racing pose)
    torso = [
        (head_cx - 8 * s, head_cy + head_r),
        (head_cx + 35 * s, head_cy + head_r - 8 * s),
        (head_cx + 45 * s, head_cy + head_r + 45 * s),
        (head_cx - 15 * s, head_cy + head_r + 35 * s),
    ]
    rd.polygon(torso, fill=(255, 255, 255, 230))

    # Arms
    rd.line(
        [(head_cx + 25 * s, head_cy + head_r + 5 * s),
         (head_cx + 75 * s, head_cy + head_r + 15 * s)],
        fill=(255, 255, 255, 210), width=max(3, int(9 * s)),
    )
    rd.line(
        [(head_cx + 15 * s, head_cy + head_r + 18 * s),
         (head_cx + 70 * s, head_cy + head_r + 30 * s)],
        fill=(255, 255, 255, 190), width=max(3, int(8 * s)),
    )

    # Legs
    rd.line(
        [(head_cx - 5 * s, head_cy + head_r + 40 * s),
         (head_cx + 15 * s, head_cy + head_r + 90 * s)],
        fill=(255, 255, 255, 230), width=max(3, int(11 * s)),
    )
    rd.line(
        [(head_cx + 25 * s, head_cy + head_r + 40 * s),
         (head_cx - 5 * s, head_cy + head_r + 85 * s)],
        fill=(255, 255, 255, 210), width=max(3, int(10 * s)),
    )

    # ── 5. Bicycle wheels ──
    wheel_r = 45 * s
    # Rear wheel
    rd.ellipse(
        (cx - 50 * s - wheel_r, cy + 55 * s,
         cx - 50 * s + wheel_r, cy + 55 * s + wheel_r * 2),
        outline=(255, 255, 255, 150), width=max(3, int(6 * s)),
    )
    # Front wheel
    rd.ellipse(
        (cx + 95 * s - wheel_r, cy + 55 * s,
         cx + 95 * s + wheel_r, cy + 55 * s + wheel_r * 2),
        outline=(255, 255, 255, 150), width=max(3, int(6 * s)),
    )
    # Frame
    rd.line(
        [(cx - 50 * s, cy + 55 * s + wheel_r),
         (cx + 25 * s, cy - 15 * s),
         (cx + 95 * s, cy + 55 * s + wheel_r)],
        fill=(255, 255, 255, 160), width=max(3, int(6 * s)),
    )
    rd.line(
        [(cx - 50 * s, cy + 55 * s + wheel_r),
         (cx + 95 * s, cy + 55 * s + wheel_r)],
        fill=(255, 255, 255, 140), width=max(3, int(5 * s)),
    )

    # ── 6. Map pin (location marker) ──
    pin_s = 40 * s
    pin_x, pin_y = cx - 130 * s, cy + 40 * s
    rd.ellipse(
        (pin_x - pin_s, pin_y - pin_s, pin_x + pin_s, pin_y + pin_s),
        fill=(255, 60, 60, 200),
    )
    rd.polygon(
        [(pin_x - pin_s * 0.3, pin_y),
         (pin_x + pin_s * 0.3, pin_y),
         (pin_x, pin_y + pin_s * 1.4)],
        fill=(255, 60, 60, 220),
    )
    rd.ellipse(
        (pin_x - pin_s * 0.25, pin_y - pin_s * 0.25,
         pin_x + pin_s * 0.25, pin_y + pin_s * 0.25),
        fill=(255, 255, 255, 240),
    )

    # ── 7. Speed lines ──
    for i in range(10):
        angle = math.radians(i * 36 + 10)
        dist = r - 20 * s
        x1 = cx + math.cos(angle) * dist
        y1 = cy + math.sin(angle) * dist
        x2 = cx + math.cos(angle) * (dist + 18 * s)
        y2 = cy + math.sin(angle) * (dist + 18 * s)
        rd.line(
            [(x1, y1), (x2, y2)],
            fill=(255, 255, 255, 80),
            width=max(2, int(4 * s)),
        )

    # ── 8. Drop shadow ──
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(
        (cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3),
        fill=(0, 0, 0, 80),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=size * 0.025))
    img = Image.alpha_composite(shadow, img)

    return img


def save_android_icons(img):
    base = os.path.join(os.path.dirname(os.path.dirname(__file__)), "android", "app", "src", "main")
    for folder, size in ANDROID.items():
        dir_path = os.path.join(base, "res", folder)
        os.makedirs(dir_path, exist_ok=True)
        resized = img.resize((size, size), Image.LANCZOS)
        path = os.path.join(dir_path, "ic_launcher.png")
        bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        bg.paste(resized, (0, 0), resized)
        bg.save(path, "PNG")
        print(f"  ✓ {folder}/ic_launcher.png  ({size}x{size})")


def save_web_icons(img):
    base = os.path.join(os.path.dirname(os.path.dirname(__file__)), "web", "icons")
    os.makedirs(base, exist_ok=True)
    for name, size in WEB.items():
        resized = img.resize((size, size), Image.LANCZOS)
        bg = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        bg.paste(resized, (0, 0), resized)
        bg.save(os.path.join(base, name), "PNG")
        print(f"  ✓ web/icons/{name}  ({size}x{size})")
    fav = img.resize((64, 64), Image.LANCZOS)
    bg = Image.new("RGBA", (64, 64), (255, 255, 255, 0))
    bg.paste(fav, (0, 0), fav)
    bg.save(os.path.join(base, "favicon.png"), "PNG")
    print(f"  ✓ web/icons/favicon.png  (64x64)")


def save_ios_icons(img):
    base = os.path.join(os.path.dirname(os.path.dirname(__file__)), "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(base, exist_ok=True)
    for name, size in IOS.items():
        resized = img.resize((size, size), Image.LANCZOS)
        bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        bg.paste(resized, (0, 0), resized)
        bg.save(os.path.join(base, name), "PNG")
        print(f"  ✓ ios/…/{name}  ({size}x{size})")


def save_logo(img):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "app_logo.png")
    img.save(path, "PNG")
    print(f"  ✓ assets/images/app_logo.png  ({LOGO_SIZE}x{LOGO_SIZE})")


def main():
    print("╔══════════════════════════════════════╗")
    print("║   🚴 RideClub — Logo v2             ║")
    print("╚══════════════════════════════════════╝")
    print()

    print("Generating master logo (1024x1024)...")
    logo = generate_logo(LOGO_SIZE)
    save_logo(logo)

    print("\nGenerating Android launcher icons...")
    save_android_icons(logo)

    print("\nGenerating Web PWA icons...")
    save_web_icons(logo)

    print("\nGenerating iOS app icons...")
    save_ios_icons(logo)

    print("\n✅ All icons generated successfully!")


if __name__ == "__main__":
    main()