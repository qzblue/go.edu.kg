"""
Icon processor: converts the app logo JPG to PNG + ICO files.

Usage:
    python tools/process_icon.py [input_jpg]

Default input: D:/Users/yjzy0/Downloads/photo_2026-03-17_04-35-45.jpg
Requires: pip install Pillow
"""

import sys
import os
from PIL import Image

DEFAULT_INPUT = r"D:\Users\yjzy0\Downloads\photo_2026-03-17_04-35-45.jpg"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

OUTPUT_PNG = os.path.join(PROJECT_ROOT, "assets", "images", "icon.png")
OUTPUT_ICO = os.path.join(PROJECT_ROOT, "assets", "images", "icon.ico")
OUTPUT_WIN_ICO = os.path.join(PROJECT_ROOT, "windows", "runner", "resources", "app_icon.ico")

ICO_SIZES = [256, 128, 64, 48, 32, 16]


def main():
    input_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_INPUT

    if not os.path.exists(input_path):
        print(f"ERROR: Input file not found: {input_path}")
        sys.exit(1)

    print(f"Loading: {input_path}")
    src = Image.open(input_path).convert("RGBA")

    # Crop to square (center crop)
    w, h = src.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    src = src.crop((left, top, left + side, top + side))

    # Save 1024x1024 PNG
    result_1024 = src.resize((1024, 1024), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUTPUT_PNG), exist_ok=True)
    result_1024.save(OUTPUT_PNG, "PNG")
    print(f"Saved PNG: {OUTPUT_PNG}")

    # Generate ICO with multiple sizes
    ico_images = [src.resize((s, s), Image.LANCZOS) for s in ICO_SIZES]
    os.makedirs(os.path.dirname(OUTPUT_ICO), exist_ok=True)
    ico_images[0].save(
        OUTPUT_ICO,
        format="ICO",
        sizes=[(s, s) for s in ICO_SIZES],
        append_images=ico_images[1:],
    )
    print(f"Saved ICO: {OUTPUT_ICO}")

    os.makedirs(os.path.dirname(OUTPUT_WIN_ICO), exist_ok=True)
    ico_images[0].save(
        OUTPUT_WIN_ICO,
        format="ICO",
        sizes=[(s, s) for s in ICO_SIZES],
        append_images=ico_images[1:],
    )
    print(f"Saved Windows ICO: {OUTPUT_WIN_ICO}")
    print("Done!")


if __name__ == "__main__":
    main()
