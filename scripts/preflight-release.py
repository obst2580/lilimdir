#!/usr/bin/env python3
"""Inspect a release app and run a local sandbox probe; never upload the app.

The candidate bundle is not modified. The sandbox probe builds its own app and
fixtures under .build/sandbox-probe.
"""
import argparse
import plistlib
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("app", type=Path)
parser.add_argument("--channel", choices=["store", "direct"], default="store")
args = parser.parse_args()
failures = []


def check(ok, label):
    print(("PASS" if ok else "FAIL") + " · " + label)
    if not ok:
        failures.append(label)


app = args.app.resolve()
check(app.is_dir(), "app bundle exists")
if not app.is_dir():
    raise SystemExit(1)
with (app / "Contents/Info.plist").open("rb") as source:
    info = plistlib.load(source)
binary = app / "Contents/MacOS" / info["CFBundleExecutable"]
check(binary.is_file(), "main executable exists")
check(all("$(" not in str(info.get(k, "")) for k in ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleShortVersionString")),
      "bundle settings have been expanded")
check(bool(info.get("LSApplicationCategoryType")), "app category is declared")
manifest = app / "Contents/Resources/PrivacyInfo.xcprivacy"
check(manifest.is_file(), "privacy manifest is included")
if manifest.is_file():
    with manifest.open("rb") as source:
        privacy = plistlib.load(source)
    categories = {item["NSPrivacyAccessedAPIType"]: item.get("NSPrivacyAccessedAPITypeReasons", [])
                  for item in privacy.get("NSPrivacyAccessedAPITypes", [])}
    check(bool(categories.get("NSPrivacyAccessedAPICategoryUserDefaults")), "preferences API reason is declared")
    check(bool(categories.get("NSPrivacyAccessedAPICategoryFileTimestamp")), "file timestamp API reason is declared")
verified = subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], capture_output=True)
check(verified.returncode == 0, "code signature is valid")
signature = subprocess.run(["codesign", "--display", "--verbose=4", str(app)], capture_output=True, text=True)
details = signature.stderr
check("TeamIdentifier=" in details and "TeamIdentifier=not set" not in details, "developer team signature is present")
if args.channel == "store":
    entitlements = subprocess.run(["codesign", "--display", "--entitlements", "-", "--xml", str(app)], capture_output=True)
    try:
        rights = plistlib.loads(entitlements.stdout)
    except (plistlib.InvalidFileException, ValueError):
        rights = {}
    check(rights.get("com.apple.security.app-sandbox") is True, "App Sandbox is enabled")
    check(rights.get("com.apple.security.files.user-selected.read-write") is True, "user-selected folder access is enabled")
    probe = subprocess.run(["bash", "scripts/check-sandbox.sh"], cwd=Path(__file__).resolve().parents[1], capture_output=True, text=True)
    print(probe.stdout.strip())
    check(probe.returncode == 0, "sandbox terminal regression checks pass")
else:
    check("Developer ID Application" in details, "Developer ID distribution identity is used")
    assessed = subprocess.run(["spctl", "--assess", "--type", "execute", str(app)], capture_output=True)
    check(assessed.returncode == 0, "Gatekeeper accepts the release app")
print(f"Release checks: {len(failures)} unresolved item(s).")
print("This checks the local binary; account contracts, store metadata, pricing, review, and publishing are separate.")
raise SystemExit(1 if failures else 0)
