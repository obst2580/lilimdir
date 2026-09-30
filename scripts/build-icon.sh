#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

source_icon="$PWD/App/Assets/AppIcon.png"
iconset_dir="$PWD/.build/icons/AppIcon.iconset"
mkdir -p "$iconset_dir"

# Native macOS sizes, including Retina representations. Keep the source alpha.
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$source_icon" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$source_icon" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset_dir" -o "$PWD/.build/icons/AppIcon.icns"
sips -z 256 256 "$source_icon" --out "$PWD/.build/icons/LilimIcon.png" >/dev/null
