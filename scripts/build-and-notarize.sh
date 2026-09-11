#!/bin/bash
set -e

echo "🔨 Building Release version..."
./scripts/build.sh Release

echo "🔑 Signing for notarization..."
./scripts/sign-for-notarization.sh "/Users/deiondrickroberts/Library/Developer/Xcode/DerivedData/ScreenResize/Build/Products/Release/ScreenResize.app"

echo "📤 Notarizing app..."
./scripts/notarize.sh "/Users/deiondrickroberts/Library/Developer/Xcode/DerivedData/ScreenResize/Build/Products/Release/ScreenResize.app"

echo "✅ Build complete!"
