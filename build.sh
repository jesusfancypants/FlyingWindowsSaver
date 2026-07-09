#!/bin/zsh
set -euo pipefail

MODULE="FlyingWindowsSaver"
SAVER_NAME="Flying Windows.saver"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
BUILD_VERSION="$(date +%s)"
ARCH_TARGETS=("arm64-apple-macosx12.0" "x86_64-apple-macosx12.0")

SHARED_SOURCES=("$ROOT"/Sources/*.swift)

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/arch"

# Kill any running screen-saver host processes so the next activation is
# guaranteed to dlopen the binary we're about to install, not an old one
# still resident in a lingering legacyScreenSaver.appex process (Apple's
# hosting has known bugs around not restarting these on its own).
pkill -f "legacyScreenSaver.appex" 2>/dev/null || true

# Builds a universal (arm64 + x86_64) library by compiling each slice
# separately (via swiftc -target) and combining them with lipo.
build_universal() {
  local module_name="$1"
  local out_path="$2"
  local slices=()
  for target in "${ARCH_TARGETS[@]}"; do
    local slice="$BUILD_DIR/arch/${module_name}-${target%%-*}"
    swiftc "${SHARED_SOURCES[@]}" -emit-library -O -module-name "$module_name" \
      -o "$slice" -target "$target" -framework ScreenSaver -framework AppKit
    slices+=("$slice")
  done
  lipo -create -output "$out_path" "${slices[@]}"
}

# --- Flying Windows.saver ---
SAVER_BUNDLE="$BUILD_DIR/$SAVER_NAME"
mkdir -p "$SAVER_BUNDLE/Contents/MacOS" "$SAVER_BUNDLE/Contents/Resources"
build_universal "$MODULE" "$SAVER_BUNDLE/Contents/MacOS/$MODULE"

chmod +x "$SAVER_BUNDLE/Contents/MacOS/$MODULE"
cp "$ROOT/Info.plist" "$SAVER_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_VERSION" "$SAVER_BUNDLE/Contents/Info.plist"
codesign --force --deep --sign - "$SAVER_BUNDLE"

DEST="$HOME/Library/Screen Savers/$SAVER_NAME"
mkdir -p "$HOME/Library/Screen Savers"
rm -rf "$DEST"
cp -R "$SAVER_BUNDLE" "$DEST"
echo "Installed screen saver (build $BUILD_VERSION) to $DEST"

open "$DEST"
