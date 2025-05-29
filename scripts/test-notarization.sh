#!/bin/bash
# Test notarization script using existing app and environment variables

set -eo pipefail

log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

cd /Users/steipete/Projects/CodeLooper

# Check if app exists
APP_PATH="binary/CodeLooper.app"
if [ ! -d "$APP_PATH" ]; then
    log "❌ App not found at $APP_PATH"
    exit 1
fi

log "✅ App found at $APP_PATH"

# Check environment variables
if [ -z "$APP_STORE_CONNECT_API_KEY_P8_CONTENT" ]; then
    log "❌ APP_STORE_CONNECT_API_KEY_P8_CONTENT not set"
    exit 1
fi

if [ -z "$APP_STORE_CONNECT_KEY_ID" ] || [ -z "$APP_STORE_CONNECT_ISSUER_ID" ]; then
    log "❌ App Store Connect credentials not complete"
    exit 1
fi

log "✅ Environment variables are set"

# Check rcodesign
RCODESIGN_PATH="tools/rcodesign/bin/rcodesign"
if [ ! -f "$RCODESIGN_PATH" ]; then
    log "❌ rcodesign not found at $RCODESIGN_PATH"
    exit 1
fi

log "✅ rcodesign found"

# Create temporary P8 file
TEMP_P8_FILE=$(mktemp /tmp/notary_key.XXXXXX.p8)
echo -e "$APP_STORE_CONNECT_API_KEY_P8_CONTENT" > "$TEMP_P8_FILE"

# Cleanup function
cleanup() {
    rm -f "$TEMP_P8_FILE"
    log "Cleaned up temporary files"
}
trap cleanup EXIT

# Create API key JSON file for rcodesign
TEMP_API_KEY_JSON=$(mktemp /tmp/api_key.XXXXXX.json)

log "🔧 Encoding App Store Connect API Key..."
"$RCODESIGN_PATH" encode-app-store-connect-api-key \
    "$APP_STORE_CONNECT_ISSUER_ID" \
    "$APP_STORE_CONNECT_KEY_ID" \
    "$TEMP_P8_FILE" \
    --output-path "$TEMP_API_KEY_JSON"

if [ $? -ne 0 ]; then
    log "❌ Failed to encode API key"
    exit 1
fi

# Update cleanup function
cleanup() {
    rm -f "$TEMP_P8_FILE" "$TEMP_API_KEY_JSON"
    log "Cleaned up temporary files"
}

# Test notarization
log "🚀 Starting notarization test..."
log "Using Key ID: $APP_STORE_CONNECT_KEY_ID"
log "Using Issuer ID: $APP_STORE_CONNECT_ISSUER_ID"

"$RCODESIGN_PATH" notary-submit \
    --api-key-path "$TEMP_API_KEY_JSON" \
    --wait \
    "$APP_PATH"

if [ $? -eq 0 ]; then
    log "✅ Notarization successful!"
    
    # Verify with spctl
    log "🔍 Verifying with spctl..."
    spctl --assess --type execute --verbose "$APP_PATH"
    
    if [ $? -eq 0 ]; then
        log "✅ spctl verification passed!"
    else
        log "⚠️ spctl verification failed"
    fi
else
    log "❌ Notarization failed"
    exit 1
fi

log "🎉 Notarization test completed successfully!"