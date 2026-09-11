#!/bin/bash
set -e

# Notarize a Developer ID signed app and staple the ticket.
# Usage: ./scripts/notarize.sh /path/to/ScreenResize.app

if [ $# -ne 1 ]; then
    echo "Usage: $0 /path/to/ScreenResize.app"
    exit 1
fi

APP_PATH="$1"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found"
    exit 1
fi

# Get password from Keychain
APPLE_ID="drobe005@gmail.com"
KEYCHAIN_ITEM="ScreenResize-Notarization"
PASSWORD=$(security find-generic-password -a "$APPLE_ID" -s "$KEYCHAIN_ITEM" -w 2>/dev/null)
if [ -z "$PASSWORD" ]; then
    echo "Error: Could not retrieve password from Keychain"
    exit 1
fi

TEAM_ID="S77K343D39"
APP_NAME=$(basename "$APP_PATH")
ZIP_PATH="/tmp/${APP_NAME}.zip"

echo "🔐 Notarizing $APP_NAME..."
echo "📦 Creating ZIP archive..."
cd "$(dirname "$APP_PATH")"
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME" "$ZIP_PATH"

echo "📤 Submitting to Apple notary service..."
SUBMIT_RESULT=$(xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait 2>&1)

REQUEST_ID=$(echo "$SUBMIT_RESULT" | grep "id:" | head -1 | awk '{print $NF}')
if [ -z "$REQUEST_ID" ]; then
    echo "❌ Failed to get request ID from notarization"
    echo "$SUBMIT_RESULT"
    rm -f "$ZIP_PATH"
    exit 1
fi

echo "✅ Notarization complete (Request ID: $REQUEST_ID)"

# Check if it was accepted
if echo "$SUBMIT_RESULT" | grep -q "Accepted"; then
    echo "📎 Stapling notarization ticket..."
    xcrun stapler staple "$APP_PATH"
    echo "✅ Successfully notarized and stapled: $APP_PATH"
else
    echo "⚠️  Notarization status:"
    echo "$SUBMIT_RESULT"
fi

rm -f "$ZIP_PATH"
