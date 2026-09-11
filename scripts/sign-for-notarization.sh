#!/bin/bash
set -e

# Re-sign an app with proper notarization requirements:
# - Secure timestamp
# - Hardened runtime
# - No get-task-allow entitlement

if [ $# -ne 1 ]; then
    echo "Usage: $0 /path/to/ScreenResize.app"
    exit 1
fi

APP_PATH="$1"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found"
    exit 1
fi

# Get the certificate from Keychain
CERT_NAME="Developer ID Application: Deiondrick Roberts (S77K343D39)"

echo "🔑 Re-signing $APP_PATH for notarization..."
echo "   Certificate: $CERT_NAME"
echo "   Adding: --timestamp, --options runtime"

# Sign nested frameworks first (ScreenResizeCore)
FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
if [ -d "$FRAMEWORKS_DIR" ]; then
    echo "   Signing frameworks..."
    for FRAMEWORK in "$FRAMEWORKS_DIR"/*.framework; do
        if [ -d "$FRAMEWORK" ]; then
            codesign --force \
                --sign "$CERT_NAME" \
                --timestamp \
                --options runtime \
                "$FRAMEWORK"
        fi
    done
fi

# Sign the app with proper flags
codesign --force \
    --sign "$CERT_NAME" \
    --timestamp \
    --options runtime \
    --entitlements "ScreenResize/ScreenResize.entitlements" \
    "$APP_PATH"

echo "✅ Successfully re-signed for notarization"
