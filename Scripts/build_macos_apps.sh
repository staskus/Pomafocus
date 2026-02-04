#!/bin/zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DIST_DIR="$ROOT_DIR/dist/macos"
DOWNLOADS_DIR="$HOME/Downloads/Pomafocus-Builds"
BUILD_LOG="/tmp/pomafocus_macos_build.log"

echo "Building PomafocusMac.app (status bar app)..."
xcodebuild \
  -workspace "$ROOT_DIR/apps/Pomafocus.xcworkspace" \
  -scheme PomafocusMac \
  -configuration Release \
  -destination "platform=macOS" \
  build > "$BUILD_LOG"

BUILD_SETTINGS=$(xcodebuild \
  -workspace "$ROOT_DIR/apps/Pomafocus.xcworkspace" \
  -scheme PomafocusMac \
  -configuration Release \
  -showBuildSettings)

TARGET_BUILD_DIR=$(echo "$BUILD_SETTINGS" | awk -F " = " '/ TARGET_BUILD_DIR = / { print $2; exit }')
FULL_PRODUCT_NAME=$(echo "$BUILD_SETTINGS" | awk -F " = " '/ FULL_PRODUCT_NAME = / { print $2; exit }')
STATUS_APP_SOURCE="$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"

if [[ ! -d "$STATUS_APP_SOURCE" ]]; then
  echo "Unable to locate built status bar app at $STATUS_APP_SOURCE" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -R "$STATUS_APP_SOURCE" "$DIST_DIR/PomafocusMac.app"

cat > "$DIST_DIR/OpenPomafocus.command" <<'SCRIPT'
#!/bin/zsh
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
open "$HERE/PomafocusMac.app"
# Optional: open companion app if installed on this Mac.
open -b com.povilasstaskus.pomafocus.ios >/dev/null 2>&1 || true
SCRIPT
chmod +x "$DIST_DIR/OpenPomafocus.command"

rm -rf "$DOWNLOADS_DIR"
mkdir -p "$DOWNLOADS_DIR"
cp -R "$DIST_DIR/PomafocusMac.app" "$DOWNLOADS_DIR/PomafocusMac.app"
cp "$DIST_DIR/OpenPomafocus.command" "$DOWNLOADS_DIR/OpenPomafocus.command"

echo "Built macOS artifacts:"
echo "  $DIST_DIR/PomafocusMac.app"
echo "  $DIST_DIR/OpenPomafocus.command"
echo
echo "Copied to:"
echo "  $DOWNLOADS_DIR"
