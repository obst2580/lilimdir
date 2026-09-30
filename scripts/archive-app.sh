#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
channel="${1:-store}"
signing="${2:-local}"
case "$channel" in
    store) scheme="Lilim-AppStore" ;;
    direct) scheme="Lilim" ;;
    *) echo 'Usage: bash scripts/archive-app.sh store|direct local|signed' >&2; exit 2 ;;
esac
case "$signing" in
    local) signing_options=(CODE_SIGNING_ALLOWED=NO) ;;
    signed)
        : "${LILIM_TEAM_ID:?Set LILIM_TEAM_ID to your Apple Developer Team ID}"
        signing_options=("DEVELOPMENT_TEAM=$LILIM_TEAM_ID")
        if [[ "$channel" == direct ]]; then
            signing_options+=("CODE_SIGN_IDENTITY=Developer ID Application")
        fi
        ;;
    *) echo 'Signing must be local or signed.' >&2; exit 2 ;;
esac
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mkdir -p .build/archives
xcodebuild -project Lilim.xcodeproj -scheme "$scheme" -configuration Release \
    -derivedDataPath ".build/xcode-$channel" -archivePath ".build/archives/$scheme.xcarchive" \
    "${signing_options[@]}" archive
if [[ "$signing" == local ]]; then
    echo 'Local verification archive only: no distribution certificate or store submission.'
fi
