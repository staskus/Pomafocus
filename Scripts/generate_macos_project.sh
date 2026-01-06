#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MAC_DIR="$SCRIPT_DIR/../apps/macos"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: XcodeGen is required (brew install xcodegen)" >&2
  exit 1
fi

cd "$MAC_DIR"
xcodegen generate
echo "Generated $MAC_DIR/PomafocusMac.xcodeproj"
