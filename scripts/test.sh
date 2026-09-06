#!/bin/bash
#
# Run the ScreenResize unit tests from the command line.
#
# Usage:
#   ./scripts/test.sh [-only-testing:TARGET/CLASS/METHOD ...]
#
# Examples:
#   ./scripts/test.sh
#   ./scripts/test.sh -only-testing:ScreenResizeTests/GeometryTests
#
# Tests must never require Accessibility permission or a real window: the AX
# layer is mocked behind its protocol. See CLAUDE.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PROJECT="ScreenResize.xcodeproj"
SCHEME="ScreenResize"
CONFIGURATION="Debug"
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

echo "==> Testing $SCHEME ($CONFIGURATION)"

XCODEBUILD_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "platform=macOS"
  -derivedDataPath "$DERIVED_DATA"
  test
)

# Any extra arguments (e.g. -only-testing:...) are passed straight through.
if [ "$#" -gt 0 ]; then
  XCODEBUILD_ARGS+=("$@")
fi

if command -v xcbeautify >/dev/null 2>&1; then
  set -o pipefail
  xcodebuild "${XCODEBUILD_ARGS[@]}" | xcbeautify
else
  xcodebuild "${XCODEBUILD_ARGS[@]}"
fi

echo "==> Tests passed"
