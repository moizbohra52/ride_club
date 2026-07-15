#!/usr/bin/env python3
"""
Convert rideclube.png to full app logo + all platform launcher icons.
"""

import os
from PIL import Image

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

SRC = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "images", "rideclube.png")

def main():
    print("╔══════════════════════════════════════╗")
    print("║   RideClub — Convert rideclube.png   ║")
    print("╚══════════════════════════════════════╝")

    if not os.path.exists(SRC):
        print(f"❌ Source file not found: {SRC}")
        return

    # Open original (RGB, 1254x1254)
    img_rgb = Image.open(SRC)
    print(f"  Original: {img_rgb.size} {img_rgb.mode}")

    # Convert to RGBA, fill background with white if needed
    if img_rgb.mode != "RGBA":
        img = img_rgb.convert("RGBA")
    else:
        img = img_rgb

    # Save master logo at 1024x1024 (app_logo.png)
    logo_1024 = img.resize((1024, 1024), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    logo_path = os.path.join(OUT, "app_logo.png")
    logo_1024.save(logo_path, "PNG")
    print(f"  ✓ assets/images/app_logo.png (1024x1024)")

    # ── Android icons ──
    base_android = os.path.join(os.path.dirname(os.path.dirname(__file__)), "android", "app", "src", "main")
    for folder, size in ANDROID.items():
        dir_path = os.path.join(base_android, "res", folder)
        os.makedirs(dir_path, exist_ok=True)
        resized = img.resize((size, size), Image.LANCZOS)
        bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        bg.paste(resized, (0, 0), resized)
        bg.save(os.path.join(dir_path, "ic_launcher.png"), "PNG")
        print(f"  ✓ android/res/{folder}/ic_launcher.png ({size}x{size})")

    # ── Web icons ──
    base_web = os.path.join(os.path.dirname(os.path.dirname(__file__)), "web", "icons")
    os.makedirs(base_web, exist_ok=True)
    for name, size in WEB.items():
        resized = img.resize((size, size), Image.LANCZOS)
        bg = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        bg.paste(resized, (0, 0), resized)
        bg.save(os.path.join(base_web, name), "PNG")
        print(f"  ✓ web/icons/{name} ({size}x{size})")

    # favicon
    fav = img.resize((64, 64), Image.LANCZOS)
    bg = Image.new("RGBA", (64, 64), (255, 255, 255, 0))
    bg.paste(fav, (0, 0), fav)
    bg.save(os.path.join(base_web, "favicon.png"), "PNG")
    print(f"  ✓ web/icons/favicon.png (64x64)")

    # ── iOS icons ──
    base_ios = os.path.join(os.path.dirname(os.path.dirname(__file__)), "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(base_ios, exist_ok=True)
    for name, size in IOS.items():
        resized = img.resize((size, size), Image.LANCZOS)
        bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        bg.paste(resized, (0, 0), resized)
        bg.save(os.path.join(base_ios, name), "PNG")
        print(f"  ✓ ios/…/{name} ({size}x{size})")

    print("\n✅ Done! All icons generated from rideclube.png")

if __name__ == "__main__":
    main()