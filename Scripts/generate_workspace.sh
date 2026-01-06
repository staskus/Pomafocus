#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR="$SCRIPT_DIR/.."
APPS_DIR="$ROOT_DIR/apps"

"$SCRIPT_DIR/generate_ios_project.sh"
"$SCRIPT_DIR/generate_macos_project.sh"

WORKSPACE_DIR="$APPS_DIR/Pomafocus.xcworkspace"
mkdir -p "$WORKSPACE_DIR"
cat <<'XML' > "$WORKSPACE_DIR/contents.xcworkspacedata"
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version="1.0">
   <FileRef location="group:ios/Pomafocus.xcodeproj"></FileRef>
   <FileRef location="group:macos/PomafocusMac.xcodeproj"></FileRef>
</Workspace>
XML

echo "Generated $WORKSPACE_DIR"
