#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
probe_dir="$PWD/.build/sandbox-probe"
app_dir="$probe_dir/Lilim Sandbox Probe.app"
mkdir -p "$app_dir/Contents/MacOS"
clang -c Sources/PTYBridge/PTYBridge.c -I Sources/PTYBridge/include -o "$probe_dir/pty.o"
swiftc -swift-version 6 -parse-as-library -I Sources/PTYBridge/include \
    Tests/SandboxProbe.swift "$probe_dir/pty.o" -o "$app_dir/Contents/MacOS/SandboxProbe"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.lilim.sandbox-probe</string>
<key>CFBundleExecutable</key><string>SandboxProbe</string>
<key>CFBundleName</key><string>Lilim Sandbox Probe</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
codesign --force --sign - --entitlements App/AppStore.entitlements "$app_dir"
codesign --verify --strict "$app_dir"
mkdir -p "$probe_dir/external-fixture"
printf 'sandbox external read fixture\n' > "$probe_dir/external-fixture/outside-marker.txt"
clang Tests/SandboxExternalTool.c -o "$probe_dir/external-fixture/external-tool"
"$app_dir/Contents/MacOS/SandboxProbe" --outside "$probe_dir/external-fixture" "$@"
