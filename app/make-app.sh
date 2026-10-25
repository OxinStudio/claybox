#!/bin/bash
# Builds Claybox.app for local testing:
#   - the SwiftUI app (swift build)
#   - the game engine from ../scummvm (run ../build-claybox.sh first)
#   - the Real-ESRGAN ncnn upscaler (downloaded once from its GitHub release)
set -e
cd "$(dirname "$0")"
DEV="$(cd ..; pwd)"
APP="build/Claybox.app"

# ./make-app.sh            → dev build (engine from ../scummvm, needs Homebrew)
# ./make-app.sh --release  → release build (engine from ../build-release, self-contained, macOS 14+)
if [ "$1" = "--release" ]; then
  ENGINE="$DEV/build-release/scummvm"
  [ -x "$ENGINE" ] || { echo "Build the release engine first: ../build-release-engine.sh"; exit 1; }
else
  ENGINE="$DEV/scummvm/scummvm"
  [ -x "$ENGINE" ] || { echo "Build the engine first: ../build-claybox.sh"; exit 1; }
fi

echo "• Building the app…"
swift build -c release

echo "• Getting the upscaler (once)…"
if [ ! -x vendor/upscaler/realesrgan-ncnn-vulkan ]; then
  mkdir -p vendor && cd vendor
  curl -fL -o esrgan.zip https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-macos.zip
  rm -rf upscaler && mkdir upscaler && unzip -q esrgan.zip -d upscaler && rm esrgan.zip
  # the zip may contain a top-level folder
  BIN=$(find upscaler -name realesrgan-ncnn-vulkan -type f | head -1)
  [ "$BIN" != "upscaler/realesrgan-ncnn-vulkan" ] && mv "$(dirname "$BIN")"/* upscaler/
  chmod +x upscaler/realesrgan-ncnn-vulkan
  xattr -dr com.apple.quarantine upscaler 2>/dev/null || true
  cd ..
fi

echo "• Assembling Claybox.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/engine" "$APP/Contents/Resources/engine-data" "$APP/Contents/Resources/upscaler"
cp .build/release/Claybox "$APP/Contents/MacOS/Claybox"
cp "$ENGINE" "$APP/Contents/MacOS/claybox-engine"
cp Info.plist "$APP/Contents/Info.plist"
cp Claybox.icns "$APP/Contents/Resources/Claybox.icns"
cp "$DEV/scummvm/dists/engine-data/neverhood.dat" "$APP/Contents/Resources/engine-data/"
cp vendor/upscaler/realesrgan-ncnn-vulkan "$APP/Contents/MacOS/realesrgan-ncnn-vulkan"
cp -R vendor/upscaler/models "$APP/Contents/Resources/upscaler/models"
for f in COPYING LICENSES AUTHORS; do
  [ -e "$DEV/scummvm/$f" ] && cp -R "$DEV/scummvm/$f" "$APP/Contents/Resources/engine/" || true
done

# ad-hoc signature for running on this Mac (release builds get a Developer ID signature)
codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true
echo "Done: $(pwd)/$APP"
echo "Run it with:  open \"$(pwd)/$APP\""
