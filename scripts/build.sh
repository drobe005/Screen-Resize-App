#!/bin/bash
#
# Build ScreenResize from the command line.
#
# Usage:
#   ./scripts/build.sh [CONFIGURATION]
#
# CONFIGURATION defaults to Debug. Pass Release for a release build.
#
# This project is never built from the Xcode GUI. See CLAUDE.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PROJECT="ScreenResize.xcodeproj"
SCHEME="ScreenResize"
CONFIGURATION="${1:-Debug}"
# DerivedData deliberately lives OUTSIDE the repo. This project sits under
# ~/Documents, which iCloud's "Desktop & Documents Folders" sync manages via a
# file provider. That provider stamps com.apple.FinderInfo and
# com.apple.fileprovider.fpfs#P onto anything written there, and codesign
# refuses to sign a bundle carrying them ("resource fork, Finder information,
# or similar detritus not allowed"). Building outside the synced tree avoids it.
# Override with SCREENRESIZE_DERIVED_DATA if you need a different location.
DERIVED_DATA="${SCREENRESIZE_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/ScreenResize}"

if [ ! -d "$PROJECT" ]; then
  echo "error: $PROJECT not found in $REPO_ROOT" >&2
  echo "The app has not been scaffolded yet." >&2
  exit 1
fi

echo "==> Building $SCHEME ($CONFIGURATION)"

XCODEBUILD_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "platform=macOS"
  -derivedDataPath "$DERIVED_DATA"
  build
)

if command -v xcbeautify >/dev/null 2>&1; then
  set -o pipefail
  xcodebuild "${XCODEBUILD_ARGS[@]}" | xcbeautify
else
  xcodebuild "${XCODEBUILD_ARGS[@]}"
fi

echo "==> Build succeeded"
echo "    Product: $DERIVED_DATA/Build/Products/$CONFIGURATION/$SCHEME.app"
