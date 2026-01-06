#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
IOS_DIR="$SCRIPT_DIR/../apps/ios"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: XcodeGen is required (brew install xcodegen)" >&2
  exit 1
fi

cd "$IOS_DIR"
xcodegen generate
echo "Generated $IOS_DIR/Pomafocus.xcodeproj"
