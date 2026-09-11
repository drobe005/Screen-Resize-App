#!/bin/bash

# Monitor notarization progress and notify when complete
# Usage: ./scripts/monitor-notarization.sh

OUTPUT_FILE="/private/tmp/claude-501/-Users-deiondrickroberts-Documents-Development-Screen-Scaling-Tool/4c35d02f-1bbc-4dd0-a832-ae32df6860e4/tasks/bru5v1dyz.output"
CHECK_INTERVAL=30
MAX_WAIT=$((20 * 60))  # 20 minutes max

echo "🔍 Monitoring notarization (updates every $CHECK_INTERVAL seconds)..."
echo "Press Ctrl+C to stop monitoring"

ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
        # File has content
        CONTENT=$(cat "$OUTPUT_FILE")

        if echo "$CONTENT" | grep -q "Accepted"; then
            echo ""
            echo "✅ NOTARIZATION SUCCESSFUL!"
            echo ""
            echo "$CONTENT" | tail -5

            # Send macOS notification
            osascript -e 'display notification "ScreenResize notarization complete!" with title "ScreenResize"' 2>/dev/null

            echo ""
            echo "📎 Verifying ticket stapled to app..."
            stapler validate ~/Applications/ScreenResize.app 2>/dev/null && echo "✅ Ticket verified!" || echo "⚠️  Ticket verification status unknown"
            exit 0
        elif echo "$CONTENT" | grep -q "Invalid"; then
            echo ""
            echo "❌ NOTARIZATION FAILED"
            echo ""
            tail -20 "$OUTPUT_FILE"
            exit 1
        fi
    fi

    ELAPSED=$((ELAPSED + CHECK_INTERVAL))
    REMAINING=$((MAX_WAIT - ELAPSED))
    MINS=$((REMAINING / 60))
    SECS=$((REMAINING % 60))

    echo -ne "\r⏱️  Still processing... ($MINS:$(printf '%02d' $SECS) remaining)  "
    sleep $CHECK_INTERVAL
done

echo ""
echo "⏰ Notarization is taking longer than expected."
echo "   Apple's service can take up to 20 minutes."
echo ""
echo "Check status manually:"
echo "   tail -f $OUTPUT_FILE"
echo "   OR"
echo "   stapler validate ~/Applications/ScreenResize.app"
