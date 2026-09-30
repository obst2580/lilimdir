#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Build both Mac architectures from the current sources. This is a private
# test package, not a Developer ID signed or notarized distribution.
bash scripts/archive-app.sh direct local
stage_root="$(mktemp -d "$PWD/.build/test-package.XXXXXX")"
trap 'rm -rf "$stage_root"' EXIT
app_dir="$stage_root/Lilim.app"
ditto .build/archives/Lilim.xcarchive/Products/Applications/Lilim.app "$app_dir"
codesign --force --deep --options runtime --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
archs="$(lipo -archs "$app_dir/Contents/MacOS/Lilim")"
[[ " $archs " == *" arm64 "* && " $archs " == *" x86_64 "* ]]

cat > "$stage_root/INSTALL.txt" <<'GUIDE'
Lilim 0.1.0 · 비공개 테스트 버전

지원: macOS 14 이상, Apple Silicon(M 시리즈) 및 인텔 맥.

설치와 실행
1. ZIP 파일을 맥에서 다운로드하고 더블클릭해 압축을 풉니다.
2. Lilim.app을 Finder의 응용 프로그램 폴더로 옮깁니다.
3. 응용 프로그램 폴더의 Lilim.app을 더블클릭합니다.
4. Dock의 Lilim 아이콘을 우클릭하고 옵션 → Dock에 유지를 선택합니다.

첫 실행 안내
이 테스트 버전은 Apple 배포 서명·공증 전입니다. macOS가 실행을 차단할 수 있습니다.
보낸 개발자가 누구인지 확인하고, 이 앱의 실행을 신뢰하는 경우에만
Apple의 아래 안내에 따라 시스템 설정 → 개인정보 보호 및 보안에서
해당 앱에 대한 열기 예외를 직접 선택하세요. 버튼 표시는 macOS 버전에 따라 다릅니다.
설정으로 해결되지 않으면 경고 문구와 macOS 버전을 개발자에게 알려 주세요.
https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac

사용법
- 왼쪽에서 폴더를 클릭하면 오른쪽의 현재 터미널 탭이 해당 경로로 이동합니다.
- 새 터미널 탭은 + 버튼, Command+T 또는 폴더 우클릭 메뉴로 엽니다.
- 폴더의 별, 우클릭 메뉴, 즐겨찾기 옆 +로 즐겨찾기를 추가합니다.
- Command+L로 경로를 입력하고 Command+F로 현재 폴더와 하위 폴더를 검색합니다.

테스트 피드백
문제가 생기면 수행한 동작, 기대한 결과, 실제 결과, macOS 버전과 함께 알려 주세요.
스크린샷에서는 개인 파일명이나 터미널의 민감한 내용을 가려 주세요.
GUIDE

mkdir -p dist
package_path="$PWD/dist/Lilim-0.1.0-test-universal-$(TZ=Asia/Seoul date +%Y%m%d-%H%M%S).zip"
[[ ! -e "$package_path" ]]
ditto -c -k --sequesterRsrc "$stage_root" "$package_path"

# Validate the actual ZIP after extraction rather than only the input app.
verify_root="$(mktemp -d "$stage_root/verify.XXXXXX")"
ditto -x -k "$package_path" "$verify_root"
codesign --verify --deep --strict "$verify_root/Lilim.app"
[[ -s "$verify_root/INSTALL.txt" ]]
lipo -archs "$verify_root/Lilim.app/Contents/MacOS/Lilim"
echo "$package_path"
