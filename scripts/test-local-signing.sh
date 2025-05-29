#!/bin/bash
# Test script for local code signing with Developer ID

set -eo pipefail

log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Check if we have the Developer ID certificate
DEVELOPER_ID_IDENTITY="Developer ID Application: Peter Steinberger (Y5PE65HELJ)"

log "Checking for Developer ID certificate..."
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    log "✅ Developer ID Application certificate found"
    security find-identity -v -p codesigning | grep "Developer ID Application"
else
    log "❌ Developer ID Application certificate not found"
    log "Please ensure you have a valid Developer ID Application certificate in your keychain"
    exit 1
fi

# Test basic signing
APP_PATH="binary/CodeLooper.app"
if [ -d "$APP_PATH" ]; then
    log "Testing code signing on existing app..."
    codesign --force --deep --sign "$DEVELOPER_ID_IDENTITY" "$APP_PATH"
    
    if [ $? -eq 0 ]; then
        log "✅ Code signing successful"
        
        # Verify signature
        log "Verifying signature..."
        codesign --verify --verbose "$APP_PATH"
        
        if [ $? -eq 0 ]; then
            log "✅ Signature verification passed"
        else
            log "❌ Signature verification failed"
        fi
    else
        log "❌ Code signing failed"
    fi
else
    log "⚠️  No app bundle found at $APP_PATH. Build the app first."
    log "Run: ./scripts/build.sh"
fi