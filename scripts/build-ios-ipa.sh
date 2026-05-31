#!/bin/bash
#
# Build an .ipa of the AmbiDash iOS app for GitHub-release distribution.
#
#   ./scripts/build-ios-ipa.sh
#
# Output: build/AmbiDash.ipa
#
# This produces an UNSIGNED device build packaged as an .ipa. It is meant for
# sideloading (AltStore / Sideloadly / Xcode), which re-signs the app with the
# installer's own Apple ID on install — no provisioning profile or registered
# UDIDs needed here. It will NOT install by just airdropping it; use a sideload
# tool. (For a signed ad-hoc .ipa instead, archive in Xcode and Distribute →
# Ad Hoc / Development with registered device UDIDs.)
#
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="ambidash"
OUT_DIR="build"
DD="$OUT_DIR/ios-dd"
IPA="$OUT_DIR/AmbiDash.ipa"

rm -rf "$DD" "$IPA" "$OUT_DIR/Payload"
mkdir -p "$OUT_DIR"

echo "▸ Regenerating project (xcodegen)..."
xcodegen generate >/dev/null

echo "▸ Building $SCHEME (Release, device arm64, unsigned)..."
xcodebuild -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build

APP=$(find "$DD/Build/Products/Release-iphoneos" -maxdepth 1 -name '*.app' | head -1)
[[ -n "$APP" ]] || { echo "✗ built .app not found"; exit 1; }
echo "▸ Built: $APP"

echo "▸ Packaging .ipa..."
mkdir -p "$OUT_DIR/Payload"
cp -R "$APP" "$OUT_DIR/Payload/"
( cd "$OUT_DIR" && zip -qry "AmbiDash.ipa" "Payload" && rm -rf "Payload" )

echo "✓ IPA ready: $IPA  ($(du -h "$IPA" | cut -f1))"
echo "  Install via AltStore / Sideloadly (it will re-sign with your Apple ID)."
