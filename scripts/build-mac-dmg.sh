#!/bin/bash
#
# Build a distributable .dmg of the AmbiDash macOS app.
#
#   ./scripts/build-mac-dmg.sh
#
# Output: build/AmbiDash.dmg  (drag-to-Applications layout)
#
# Signing modes (pick via env):
#   • Default (no env)      → LOCAL/TEST dmg. iCloud sync entitlements are stripped
#                             so it builds + runs without provisioning. Other Macs
#                             will see a Gatekeeper warning (right-click → Open).
#   • DEVELOPMENT_TEAM=XXXX → signs with your team (Developer ID if available).
#                             Needed for real iCloud sync + clean distribution.
#                             For public download you ALSO want to notarize — see
#                             the NOTARIZE section at the bottom of this file.
#
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="ambidash-mac"
APP_NAME="ambidash-mac"          # internal target name (product is AmbiDash.app via display name)
VOL_NAME="AmbiDash"
OUT_DIR="build"
DD="$OUT_DIR/mac-dd"
DMG_PATH="$OUT_DIR/AmbiDash.dmg"
STAGE="$OUT_DIR/dmg-stage"

rm -rf "$DD" "$STAGE" "$DMG_PATH"
mkdir -p "$OUT_DIR"

echo "▸ Regenerating project (xcodegen)…"
xcodegen generate >/dev/null

echo "▸ Building $SCHEME (Release)…"
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  # Signed build (real entitlements → iCloud sync works on your devices)
  xcodebuild -scheme "$SCHEME" -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$DD" -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
    build
else
  # Local/test build: strip the restricted iCloud/App-Group entitlements so it
  # builds + launches without a provisioning profile (no cross-device sync).
  LOCAL_ENT="$OUT_DIR/mac-local.entitlements"
  cat > "$LOCAL_ENT" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.network.client</key><true/>
  <key>com.apple.security.files.user-selected.read-write</key><true/>
</dict></plist>
PLIST
  xcodebuild -scheme "$SCHEME" -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$DD" \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_ENTITLEMENTS="$LOCAL_ENT" \
    build
fi

APP=$(find "$DD/Build/Products" -maxdepth 3 -name "$APP_NAME.app" | head -1)
[[ -n "$APP" ]] || { echo "✗ built .app not found"; exit 1; }
echo "▸ Built: $APP"

echo "▸ Staging DMG contents…"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/$VOL_NAME.app"
ln -s /Applications "$STAGE/Applications"

echo "▸ Creating ${DMG_PATH} ..."
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH" >/dev/null
rm -rf "$STAGE"

echo "✓ DMG ready: $DMG_PATH"
echo "  ($(du -h "$DMG_PATH" | cut -f1))"

# ── NOTARIZE (for public download without Gatekeeper warnings) ────────────────
# Requires a signed (DEVELOPMENT_TEAM) build with a Developer ID Application cert,
# and an App Store Connect API key or app-specific password stored as a keychain
# profile (xcrun notarytool store-credentials "AC_PROFILE" ...). Then:
#
#   xcrun notarytool submit "$DMG_PATH" --keychain-profile "AC_PROFILE" --wait
#   xcrun stapler staple "$DMG_PATH"
#
# After stapling, the .dmg opens cleanly on any Mac.
