#!/bin/bash
# codesign-app.sh - Code signing script for CodeLooper

set -eo pipefail

log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

APP_BUNDLE="${1:-binary/CodeLooper.app}"
SIGN_IDENTITY="${2:-Developer ID Application}"

if [ ! -d "$APP_BUNDLE" ]; then
    log "Error: App bundle not found at $APP_BUNDLE"
    exit 1
fi

log "Code signing $APP_BUNDLE with identity: $SIGN_IDENTITY"

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"

if [ $? -eq 0 ]; then
    log "✅ Code signing completed successfully"
else
    log "❌ Code signing failed"
    exit 1
fi

# Verify the signature
log "Verifying code signature..."
codesign --verify --verbose "$APP_BUNDLE"

if [ $? -eq 0 ]; then
    log "✅ Code signature verification passed"
else
    log "❌ Code signature verification failed"
    exit 1
fi