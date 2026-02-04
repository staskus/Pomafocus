#!/bin/zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DIST_DIR="$ROOT_DIR/dist/macos"
DOWNLOADS_DIR="$HOME/Downloads/Pomafocus-Builds"

echo "Building PomafocusMac.app (status bar app)..."
xcodebuild \
  -workspace "$ROOT_DIR/apps/Pomafocus.xcworkspace" \
  -scheme PomafocusMac \
  -configuration Release \
  -destination "platform=macOS" \
  build > /tmp/pomafocus_macos_build.log

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
cp -R "$STATUS_APP_SOURCE" "$DIST_DIR/Pomafocus.app"

cat > "$DIST_DIR/OpenPomafocusApps.command" <<'SCRIPT'
#!/bin/zsh
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)

# Always launch the macOS status bar app.
if [[ -d "$HERE/PomafocusMac.app" ]]; then
  open "$HERE/PomafocusMac.app"
fi

# Try to launch companion app if installed on this Mac.
if open -b com.povilasstaskus.pomafocus.ios >/dev/null 2>&1; then
  exit 0
fi

# Fallback: launch local Pomafocus.app if present.
if [[ -d "$HERE/Pomafocus.app" ]]; then
  open "$HERE/Pomafocus.app"
  exit 0
fi

echo "Companion app is not installed. Installed app bundle id expected: com.povilasstaskus.pomafocus.ios"
exit 1
SCRIPT
chmod +x "$DIST_DIR/OpenPomafocusApps.command"

rm -rf "$DOWNLOADS_DIR"
mkdir -p "$DOWNLOADS_DIR"
cp -R "$DIST_DIR/Pomafocus.app" "$DOWNLOADS_DIR/Pomafocus.app"
cp -R "$DIST_DIR/PomafocusMac.app" "$DOWNLOADS_DIR/PomafocusMac.app"
cp "$DIST_DIR/OpenPomafocusApps.command" "$DOWNLOADS_DIR/OpenPomafocusApps.command"

echo "Built apps and launcher:"
echo "  $DIST_DIR/Pomafocus.app"
echo "  $DIST_DIR/PomafocusMac.app"
echo "  $DIST_DIR/OpenPomafocusApps.command"
echo
echo "Copied to:"
echo "  $DOWNLOADS_DIR"
