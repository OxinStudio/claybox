#!/bin/bash
# Release build of the Claybox engine: no Homebrew dependencies, runs on macOS 14+ (Apple Silicon).
#  - builds SDL2, libpng and libjpeg-turbo as static libraries for macOS 14
#  - builds ScummVM (neverhood engine + Claybox patch) out of tree in build-release/, linked statically
# Usage: ./build-release-engine.sh   (run ./build-claybox.sh once first, for the patched source)
set -e
cd "$(dirname "$0")"
DEV="$(pwd)"
export MACOSX_DEPLOYMENT_TARGET=14.0
ARCH=arm64
# ScummVM configure cannot handle spaces in paths ("The Neverhood"), so deps live in a space-free folder
DEPS="$HOME/.claybox-deps"
SRC="$DEPS/src"
mkdir -p "$SRC"
command -v cmake >/dev/null || brew install cmake

[ -d scummvm ] || { echo "Run ./build-claybox.sh first"; exit 1; }

fetch() { # url file
  [ -f "$SRC/$2" ] || curl -fL -o "$SRC/$2" "$1"
}

cmake_build() { # srcdir extra-args...
  local dir="$1"; shift
  rm -rf "$dir/build-claybox" && mkdir -p "$dir/build-claybox"
  (cd "$dir/build-claybox" && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$DEPS" \
     -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET -DCMAKE_OSX_ARCHITECTURES=$ARCH \
     -DCMAKE_PREFIX_PATH="$DEPS" -DCMAKE_FIND_FRAMEWORK=NEVER "$@" >/dev/null && \
   cmake --build . -j"$(sysctl -n hw.ncpu)" >/dev/null && cmake --install . >/dev/null)
}

if [ ! -f "$DEPS/lib/libSDL2.a" ]; then
  echo "• SDL2 (static)…"
  fetch https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.tar.gz SDL2.tar.gz
  rm -rf "$SRC/SDL2" && mkdir "$SRC/SDL2" && tar xzf "$SRC/SDL2.tar.gz" -C "$SRC/SDL2" --strip-components 1
  cmake_build "$SRC/SDL2" -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF
fi
if [ ! -f "$DEPS/lib/libpng.a" ]; then
  echo "• libpng (static)…"
  fetch https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.44.tar.gz libpng.tar.gz
  rm -rf "$SRC/libpng" && mkdir "$SRC/libpng" && tar xzf "$SRC/libpng.tar.gz" -C "$SRC/libpng" --strip-components 1
  cmake_build "$SRC/libpng" -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF -DPNG_FRAMEWORK=OFF -DPNG_TOOLS=OFF
fi
if [ ! -f "$DEPS/lib/libjpeg.a" ]; then
  echo "• libjpeg-turbo (static)…"
  fetch https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.0.4/libjpeg-turbo-3.0.4.tar.gz jpeg.tar.gz
  rm -rf "$SRC/jpeg" && mkdir "$SRC/jpeg" && tar xzf "$SRC/jpeg.tar.gz" -C "$SRC/jpeg" --strip-components 1
  cmake_build "$SRC/jpeg" -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_TURBOJPEG=OFF -DCMAKE_INSTALL_LIBDIR=lib
fi
# make sure nothing links a shared copy by accident
rm -f "$DEPS"/lib/*.dylib

echo "• Engine (release, static)…"
mkdir -p build-release
cd build-release
if [ ! -f config.mk ]; then
  # keep Homebrew out of the search paths; static SDL2 also needs the game-controller frameworks
  PATH="$DEPS/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  CXXFLAGS="-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET -arch $ARCH" \
  LDFLAGS="-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET -arch $ARCH -framework GameController -framework CoreHaptics -framework UniformTypeIdentifiers" \
  ../scummvm/configure --disable-all-engines --enable-engine=neverhood --enable-release --enable-static \
    --with-sdl-prefix="$DEPS" --with-png-prefix="$DEPS" --with-jpeg-prefix="$DEPS" \
    --disable-freetype2 --disable-fribidi --disable-libcurl --disable-cloud --disable-sdlnet \
    --disable-sparkle --disable-discord --disable-fluidsynth --disable-mad --disable-vorbis \
    --disable-flac --disable-theoradec --disable-vpx --disable-gif --disable-mpeg2 --disable-a52 \
    --disable-faad --disable-openmpt --disable-mikmod
fi
PATH="$DEPS/bin:/usr/bin:/bin:/usr/sbin:/sbin" make -j"$(sysctl -n hw.ncpu)" >/dev/null
cp ../scummvm/dists/engine-data/neverhood.dat . 2>/dev/null || true

echo
echo "Linked libraries (should be only /usr/lib and /System):"
otool -L scummvm | tail -n +2
if otool -L scummvm | grep -q -E "/opt/homebrew|/usr/local"; then
  echo "!! still depends on Homebrew — not ready for release"; exit 1
fi
echo "Minimum macOS: $(otool -l scummvm | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}')"
echo "Release engine ready: $(pwd)/scummvm"
