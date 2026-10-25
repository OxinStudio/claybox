#!/bin/bash
# Claybox release: sign (Developer ID, hardened runtime) → notarize → staple → DMG.
# One-time setup (stores your app-specific password in the Keychain):
#   xcrun notarytool store-credentials claybox --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID
set -euo pipefail
cd "$(dirname "$0")"

# Override these to sign with your own Developer ID and notarytool profile
IDENTITY="${CLAYBOX_SIGN_IDENTITY:-Developer ID Application: Oxin Studio Inc. (WT4MKCRR7T)}"
PROFILE="${CLAYBOX_NOTARY_PROFILE:-claybox}"
SRC_APP="app/build/Claybox.app"
OUT="release"
# Sign outside ~/Documents: iCloud/Finder add extended attributes there, which codesign rejects
WORK="$HOME/.claybox-release"
APP="$WORK/Claybox.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$SRC_APP/Contents/Info.plist" 2>/dev/null || echo "1.0")
DMG="$OUT/Claybox-$VERSION.dmg"

[ -d "$SRC_APP" ] || { echo "Build the app first: cd app && ./make-app.sh --release"; exit 1; }
mkdir -p "$OUT"
rm -rf "$WORK"; mkdir -p "$WORK"
ditto --norsrc --noextattr --noqtn "$SRC_APP" "$APP"
xattr -cr "$APP"

echo "• Signing (inside out)…"
for helper in "$APP/Contents/MacOS/claybox-engine" "$APP/Contents/MacOS/realesrgan-ncnn-vulkan"; do
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$helper"
done
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "• Notarizing the app (usually 2–10 min)…"
ditto -c -k --keepParent "$APP" "$OUT/Claybox-notarize.zip"
xcrun notarytool submit "$OUT/Claybox-notarize.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
rm -f "$OUT/Claybox-notarize.zip"

echo "• Building the DMG…"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Claybox" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "• Notarizing the DMG…"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

echo "• Gatekeeper check…"
spctl -a -vvv -t exec "$APP"
spctl -a -vvv -t open --context context:primary-signature "$DMG"
echo
echo "✓ Ready: $(pwd)/$DMG"
echo "  (signed app: $APP)"
