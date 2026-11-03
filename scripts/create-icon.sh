#!/bin/bash
# create-icon.sh  —  Generate AppIcon.icns from a source PNG.
# Usage:
#   ./scripts/create-icon.sh                   # uses icon-source.png in project root
#   ./scripts/create-icon.sh path/to/image.png # uses specified file

set -e

SOURCE="${1:-icon-1024.png}"
ICNS_OUT="MacinTouchApp/Resources/AppIcon.icns"

if [ ! -f "$SOURCE" ]; then
    echo "❌ Source image not found: $SOURCE"
    echo "   Usage: ./scripts/create-icon.sh [path/to/image.png]"
    exit 1
fi

echo "🎨 Source: $SOURCE"
echo "📐 Generating iconset..."

python3 << EOF
from PIL import Image
import os, sys

src_path = "$SOURCE"
out_icns = "$ICNS_OUT"
iconset_dir = "/tmp/AppIcon.iconset"
os.makedirs(iconset_dir, exist_ok=True)

src = Image.open(src_path).convert("RGBA")
w, h = src.size

# Pad to square using the corner background color
bg = src.getpixel((4, 4))
size = max(w, h)
canvas = Image.new("RGBA", (size, size), bg)
canvas.paste(src, ((size - w) // 2, (size - h) // 2), src)
base = canvas.resize((1024, 1024), Image.LANCZOS)

sizes = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024),
]

for name, px in sizes:
    base.resize((px, px), Image.LANCZOS).save(f"{iconset_dir}/{name}")
    print(f"  {name}")
EOF

iconutil -c icns /tmp/AppIcon.iconset -o "$ICNS_OUT"
rm -rf /tmp/AppIcon.iconset

SIZE=$(du -sh "$ICNS_OUT" | cut -f1)
echo "✅ $ICNS_OUT ($SIZE)"
echo ""
echo "Next: make gui  or  make dmg"
