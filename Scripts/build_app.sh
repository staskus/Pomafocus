#!/bin/zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PRODUCT_NAME=Pomafocus
BUILD_DIR="$ROOT_DIR/.build/release"
BINARY_PATH="$BUILD_DIR/$PRODUCT_NAME"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$PRODUCT_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

swift build -c release

if [[ ! -f "$BINARY_PATH" ]]; then
  echo "Unable to find built binary at $BINARY_PATH" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$RESOURCES_DIR"

cp "$BINARY_PATH" "$CONTENTS_DIR/MacOS/$PRODUCT_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

chmod +x "$CONTENTS_DIR/MacOS/$PRODUCT_NAME"

cat <<'PLIST' > "$APP_DIR/Contents/PkgInfo"
APPL????
PLIST

echo "Created app bundle at $APP_DIR"
