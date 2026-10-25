#!/bin/bash
# Claybox dev build: ScummVM (neverhood engine only) + Claybox HD patch, for macOS.
set -e
cd "$(dirname "$0")"
command -v brew >/dev/null || { echo "Homebrew is needed: https://brew.sh"; exit 1; }
brew list sdl2 >/dev/null 2>&1 || brew install sdl2
brew list libpng >/dev/null 2>&1 || brew install libpng
if [ ! -d scummvm ]; then
  git clone --filter=blob:none https://github.com/scummvm/scummvm.git scummvm
  (cd scummvm && git checkout -q a822b48a2ddd1bcdf742935f89ee94942e49539b)
fi
# (re)apply the latest Claybox patch
(cd scummvm && git checkout -q -- . && git clean -fdq engines/neverhood && git apply ../claybox-hd.patch)
cd scummvm
[ -f config.mk ] || ./configure --disable-all-engines --enable-engine=neverhood --enable-release
make -j"$(sysctl -n hw.ncpu)"
echo "Built: $(pwd)/scummvm"
