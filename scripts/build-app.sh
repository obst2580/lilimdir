#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
stage_root="$(mktemp -d "$PWD/.build/app-stage.XXXXXX")"
trap 'rm -rf "$stage_root"' EXIT
app_dir="$stage_root/Lilim.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Lilim" "$app_dir/Contents/MacOS/Lilim"
cp App/Info.plist "$app_dir/Contents/Info.plist"
cp App/PrivacyInfo.xcprivacy "$app_dir/Contents/Resources/PrivacyInfo.xcprivacy"
bash scripts/build-icon.sh
cp .build/icons/AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
cp .build/icons/LilimIcon.png "$app_dir/Contents/Resources/LilimIcon.png"
for resource_bundle in "$binary_dir"/*.bundle; do
    if [ -d "$resource_bundle" ]; then cp -R "$resource_bundle" "$app_dir/Contents/Resources/"; fi
done
codesign --force --deep --sign - "$app_dir"
# Keep a running app's executable intact. Install the finished bundle only
# after signing, and retain the previous bundle for the current process.
destination_dir="$PWD/dist/Lilim.app"
mkdir -p "$PWD/dist"
previous_dir=""
if [[ -e "$destination_dir" ]]; then
    previous_root="$(mktemp -d "$PWD/.build/previous-app.XXXXXX")"
    previous_dir="$previous_root/Lilim.app"
    mv "$destination_dir" "$previous_dir"
fi
if ! mv "$app_dir" "$destination_dir"; then
    if [[ -n "$previous_dir" ]]; then mv "$previous_dir" "$destination_dir"; fi
    exit 1
fi
echo "$destination_dir"
