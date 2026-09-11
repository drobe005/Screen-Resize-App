#!/bin/bash
set -e

# Build, notarize, and release to GitHub in one command
# Usage: ./scripts/release.sh v0.2.0 "Fixed X, added Y"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <version> [release-notes]"
    echo ""
    echo "Examples:"
    echo "  $0 v0.2.0 'Fixed shortcut recording bugs'"
    echo "  $0 v1.0.0"
    exit 1
fi

VERSION="$1"
RELEASE_NOTES="${2:-Release $VERSION}"

echo "🚀 Building, notarizing, and releasing ScreenResize $VERSION"
echo ""

# Build and notarize
echo "Step 1/4: Building and notarizing..."
./scripts/build-and-notarize.sh

# Copy to Applications for easier access
echo ""
echo "Step 2/4: Copying app to ~/Applications..."
rm -rf ~/Applications/ScreenResize.app
cp -R "/Users/deiondrickroberts/Library/Developer/Xcode/DerivedData/ScreenResize/Build/Products/Release/ScreenResize.app" ~/Applications/

# Create ZIP
echo "Step 3/4: Creating ZIP archive..."
cd ~/Applications
rm -f "ScreenResize-${VERSION}.zip"
ditto -c -k --sequesterRsrc --keepParent ScreenResize.app "ScreenResize-${VERSION}.zip"
ZIP_PATH="~/Applications/ScreenResize-${VERSION}.zip"
echo "✅ Created: $ZIP_PATH"

# Create GitHub release
echo ""
echo "Step 4/4: Creating GitHub release..."
cd "/Users/deiondrickroberts/Documents/Development/Screen Scaling Tool"

PRERELEASE_FLAG=()
if [[ "$VERSION" == *beta* || "$VERSION" == *alpha* || "$VERSION" == *rc* ]]; then
    PRERELEASE_FLAG=(--prerelease)
fi

gh release create "$VERSION" ~/Applications/"ScreenResize-${VERSION}.zip" \
    --title "$VERSION" \
    --notes "$RELEASE_NOTES" \
    "${PRERELEASE_FLAG[@]}"

echo ""
echo "✅ Release complete!"
echo ""
echo "📦 Download: https://github.com/drobe005/Screen-Resize-App/releases/tag/$VERSION"
echo "📋 Next steps: Share the release link with your testers"
