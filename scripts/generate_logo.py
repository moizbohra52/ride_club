#!/usr/bin/env python3
"""
RideClub — Logo & Launcher Icon Generator
===========================================
Generates a professional app logo, favicon, and all platform launcher icons
using Pillow.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "images")

# ── Sizes we need to output ──────────────────────────────────────────────────
# Android mipmap launcher icons
ANDROID = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}
# Web PWA icons
WEB = {
    "Icon-192.png":            192,
    "Icon-512.png":            512,
    "Icon-maskable-192.png":   192,
    "Icon-maskable-512.png":   512,
}
# iOS (Apple) standard sizes
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
    "Icon-1024.png":         1024,       # App Store
}
# Logo full-res for branding
LOGO_SIZE = 1024


def smooth_round_corner(im, rad):
    """Apply antialiased rounded corners on RGBA image."""
    circle = Image.new("L", (rad * 2, rad * 2), 0)
    draw = ImageDraw.Draw(circle)
    draw.ellipse((0, 0, rad * 2 - 1, rad * 2 - 1), fill=255)
    w, h = im.size
    alpha = Image.new("L", (w, h), 255)
    # Top-left
    alpha.paste(circle.crop((0, 0, rad, rad)), (0, 0))
    # Top-right
    alpha.paste(circle.crop((rad, 0, rad * 2, rad)), (w - rad, 0))
    # Bottom-left
    alpha.paste(circle.crop((0, rad, rad, rad * 2)), (0, h - rad))
    # Bottom-right
    alpha.paste(circle.crop((rad, rad, rad * 2, rad * 2)), (w - rad, h - rad))
    im.putalpha(Image.merge("L", (alpha,)))
    return im


def generate_logo(size):
    """Generate the RideClub logo at given size (square)."""

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx, cy = size // 2, size // 2
    r = size * 0.47   # outer radius

    # ── 1. Background gradient (simulated with concentric ellipses) ──
    # Deep navy-blue → vibrant orange/amber gradient (sunset ride feel)
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    steps = 60
    for i in range(steps, 0, -1):
        t = i / steps
        rad = r * t
        # Mix colours: start dark midnight blue, end sunset orange
        r_col = int(25 + (230 * (1 - t)))
        g_col = int(25 + (100 * (1 - t)))
        b_col = int(80 + (50 * (1 - t)))
        bg_draw.ellipse(
            (cx - rad, cy - rad, cx + rad, cy + rad),
            fill=(r_col, g_col, b_col, 255),
        )

    # Blur for smooth gradient
    bg = bg.filter(ImageFilter.GaussianBlur(radius=size * 0.04))

    # ── 2. Outer ring accent ──
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ring_draw = ImageDraw.Draw(ring)
    ring_w = size * 0.035
    ring_draw.ellipse(
        (cx - r + ring_w, cy - r + ring_w, cx + r - ring_w, cy + r - ring_w),
        outline=(255, 200, 80, 200),
        width=max(3, int(ring_w)),
    )
    img = Image.alpha_composite(bg, ring)

    # ── 3. Stylized Rider icon ──
    # Abstract cyclist / rider silhouette made from geometric shapes
    rider = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rider)

    # Scale factor
    s = size / 512
    # Rider body (leaning forward pose - cyclist silhouette)
    # Head (circle)
    head_r = 32 * s
    head_cx, head_cy = cx + 20 * s, cy - 80 * s
    rd.ellipse(
        (head_cx - head_r, head_cy - head_r, head_cx + head_r, head_cy + head_r),
        fill=(255, 255, 255, 230),
    )

    # Helmet top curve
    rd.arc(
        (head_cx - head_r * 1.1, head_cy - head_r * 1.3,
         head_cx + head_r * 1.1, head_cy + head_r * 0.1),
        start=180, end=360,
        fill=(255, 215, 0, 200),
        width=max(2, int(6 * s)),
    )

    # Torso (leaning forward)
    torso_pts = [
        (head_cx - 10 * s, head_cy + head_r),     # neck back
        (head_cx + 40 * s, head_cy + head_r - 5 * s),  # chest
        (head_cx + 50 * s, head_cy + head_r + 50 * s), # hip front
        (head_cx - 20 * s, head_cy + head_r + 40 * s), # hip back
    ]
    rd.polygon(torso_pts, fill=(255, 255, 255, 220))

    # Left arm (reaching forward to handlebar)
    rd.line(
        [(head_cx + 30 * s, head_cy + head_r),
         (head_cx + 80 * s, head_cy + head_r + 20 * s)],
        fill=(255, 255, 255, 200),
        width=max(2, int(8 * s)),
    )
    # Right arm (lower, reaching)
    rd.line(
        [(head_cx + 20 * s, head_cy + head_r + 15 * s),
         (head_cx + 75 * s, head_cy + head_r + 35 * s)],
        fill=(255, 255, 255, 180),
        width=max(2, int(7 * s)),
    )

    # Legs (pedalling)
    rd.line(
        [(head_cx - 10 * s, head_cy + head_r + 45 * s),
         (head_cx + 10 * s, head_cy + head_r + 95 * s)],
        fill=(255, 255, 255, 220),
        width=max(2, int(10 * s)),
    )
    rd.line(
        [(head_cx + 20 * s, head_cy + head_r + 45 * s),
         (head_cx - 10 * s, head_cy + head_r + 90 * s)],
        fill=(255, 255, 255, 200),
        width=max(2, int(9 * s)),
    )

    # ── 4. Bicycle / Gear icon behind rider ──
    circle_r = 90 * s
    # Wheel (back)
    rd.ellipse(
        (cx - 40 * s - circle_r, cy + 60 * s,
         cx - 40 * s + circle_r, cy + 60 * s + circle_r * 2),
        outline=(255, 255, 255, 100),
        width=max(2, int(5 * s)),
    )
    # Wheel (front)
    rd.ellipse(
        (cx + 100 * s - circle_r, cy + 60 * s,
         cx + 100 * s + circle_r, cy + 60 * s + circle_r * 2),
        outline=(255, 255, 255, 100),
        width=max(2, int(5 * s)),
    )
    # Frame lines (simple triangle)
    rd.line(
        [(cx - 40 * s, cy + 60 * s + circle_r),
         (cx + 30 * s, cy - 20 * s),
         (cx + 100 * s, cy + 60 * s + circle_r)],
        fill=(255, 255, 255, 120),
        width=max(2, int(5 * s)),
    )
    rd.line(
        [(cx - 40 * s, cy + 60 * s + circle_r),
         (cx + 100 * s, cy + 60 * s + circle_r)],
        fill=(255, 255, 255, 120),
        width=max(2, int(4 * s)),
    )

    # ── 5. Map pin / location marker (subtle, bottom left) ──
    pin_s = 50 * s
    pin_x, pin_y = cx - 120 * s, cy + 50 * s
    rd.ellipse(
        (pin_x - pin_s, pin_y - pin_s, pin_x + pin_s, pin_y + pin_s),
        fill=(255, 50, 50, 180),
    )
    rd.polygon(
        [(pin_x - pin_s * 0.3, pin_y),
         (pin_x + pin_s * 0.3, pin_y),
         (pin_x, pin_y + pin_s * 1.5)],
        fill=(255, 50, 50, 220),
    )
    # Inner dot
    rd.ellipse(
        (pin_x - pin_s * 0.25, pin_y - pin_s * 0.25,
         pin_x + pin_s * 0.25, pin_y + pin_s * 0.25),
        fill=(255, 255, 255, 230),
    )

    # ── 6. Speed lines (dynamic feel) ──
    for i in range(8):
        angle = math.radians(i * 45 + 15)
        dist = r - 25 * s
        x1 = cx + math.cos(angle) * dist
        y1 = cy + math.sin(angle) * dist
        x2 = cx + math.cos(angle) * (dist + 20 * s)
        y2 = cy + math.sin(angle) * (dist + 20 * s)
        rd.line(
            [(x1, y1), (x2, y2)],
            fill=(255, 255, 255, 60),
            width=max(1, int(3 * s)),
        )

    img = Image.alpha_composite(img, rider)

    # ── 7. Drop shadow ──
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(
        (cx - r - 5, cy - r - 5, cx + r + 5, cy + r + 5),
        fill=(0, 0, 0, 60),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=size * 0.03))
    img = Image.alpha_composite(shadow, img)

    return img


def save_android_icons(img):
    """Save Android mipmap launcher icons."""
    base = os.path.join(os.path.dirname(os.path.dirname(__file__)), "android", "app", "src", "main")
    for folder, size in ANDROID.items():
        dir_path = os.path.join(base, "res", folder)
        os.makedirs(dir_path, exist_ok=True)
        resized = img.resize((size, size), Image.LANCZOS)
        path = os.path.join(dir_path, "ic_launcher.png")
        # Android launchers don't want transparency background
        bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        bg.paste(resized, (0, 0), resized)
        bg.save(path, "PNG")
        print(f"  ✓ {folder}/ic_launcher.png  ({size}x{size})")


def save_web_icons(img):
    """Save web/favicon PWA icons."""
    base = os.path.join(os.path.dirname(os.path.dirname(__file__)), "web", "icons")
    os.makedirs(base, exist_ok=True)
    for name, size in WEB.items():
        resized = img.resize((size, size), Image.LANCZOS)
        bg = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        bg.paste(resized, (0, 0), resized)
        bg.save(os.path.join(base, name), "PNG")
        print(f"  ✓ web/icons/{name}  ({size}x{size})")

    # Also save favicon as PNG (will convert to ico manually or use as-is)
    fav = img.resize((64, 64), Image.LANCZOS)
    bg = Image.new("RGBA", (64, 64), (255, 255, 255, 0))
    bg.paste(fav, (0, 0), fav)
    bg.save(os.path.join(base, "favicon.png"), "PNG")
    print(f"  ✓ web/icons/favicon.png  (64x64)")


def save_ios_icons(img):
    """Save iOS app icon sizes."""
    base = os.path.join(os.path.dirname(os.path.dirname(__file__)), "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(base, exist_ok=True)
    for name, size in IOS.items():
        resized = img.resize((size, size), Image.LANCZOS)
        bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        bg.paste(resized, (0, 0), resized)
        bg.save(os.path.join(base, name), "PNG")
        print(f"  ✓ ios/…/{name}  ({size}x{size})")


def save_logo(img):
    """Save the high-res master logo."""
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "app_logo.png")
    img.save(path, "PNG")
    print(f"  ✓ assets/images/app_logo.png  ({LOGO_SIZE}x{LOGO_SIZE})")

    # Also save a round version
    rounded = smooth_round_corner(img.copy(), int(LOGO_SIZE * 0.12))
    path_r = os.path.join(OUT, "app_logo_rounded.png")
    rounded.save(path_r, "PNG")
    print(f"  ✓ assets/images/app_logo_rounded.png  ({LOGO_SIZE}x{LOGO_SIZE})")


def main():
    print("╔══════════════════════════════════════╗")
    print("║   🚴 RideClub — Logo Generator      ║")
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
    print("\n── App Name ──────────────────────────────")
    print("   Suggested:  RideClub")
    print("   Also good:  RideCrew  |  Peloton+  |  VroomTogether")
    print("   Current:    RideTogether (already in main.dart)")
    print()
    print("   🏆 RECOMMENDED: 'RideClub' — short, punchy, brandable")
    print()


if __name__ == "__main__":
    main()