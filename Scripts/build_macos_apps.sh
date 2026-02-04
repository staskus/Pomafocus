#!/bin/zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DIST_DIR="$ROOT_DIR/dist/macos"
DOWNLOADS_DIR="$HOME/Downloads/Pomafocus-Builds"

echo "Building Pomafocus.app (standalone)..."
"$ROOT_DIR/Scripts/build_app.sh"

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
cp -R "$ROOT_DIR/dist/Pomafocus.app" "$DIST_DIR/Pomafocus.app"
cp -R "$STATUS_APP_SOURCE" "$DIST_DIR/PomafocusMac.app"

cat > "$DIST_DIR/OpenPomafocusApps.command" <<'SCRIPT'
#!/bin/zsh
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
APPS=("Pomafocus.app" "PomafocusMac.app")
opened=0

for app in "${APPS[@]}"; do
  app_path="$HERE/$app"
  if [[ -d "$app_path" ]]; then
    open "$app_path"
    opened=1
  fi
done

if [[ $opened -eq 0 ]]; then
  echo "No app bundles found next to this launcher."
  exit 1
fi
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
