#!/bin/bash
# notarize-app.sh - Complete notarization script for CodeLooper with Sparkle
# Handles hardened runtime, proper signing of all components, and notarization

set -eo pipefail

# ============================================================================
# Configuration
# ============================================================================

log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

error() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ❌ ERROR: $1" >&2
    exit 1
}

success() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ✅ $1"
}

APP_BUNDLE="${1:-binary/CodeLooper.app}"
SIGN_IDENTITY="Developer ID Application: Peter Steinberger (Y5PE65HELJ)"

# Check required environment variables
required_vars=("APPLE_ID" "APPLE_PASSWORD" "APPLE_TEAM_ID")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        error "Required environment variable $var is not set"
    fi
done

if [ ! -d "$APP_BUNDLE" ]; then
    error "App bundle not found at $APP_BUNDLE"
fi

log "Starting complete notarization process for $APP_BUNDLE"

# ============================================================================
# Create Entitlements Files
# ============================================================================

create_entitlements() {
    local entitlements_file="$1"
    local is_xpc_service="$2"
    
    cat > "$entitlements_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
EOF

    if [ "$is_xpc_service" = "true" ]; then
        cat >> "$entitlements_file" << 'EOF'
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.inherit</key>
    <true/>
EOF
    fi

    cat >> "$entitlements_file" << 'EOF'
</dict>
</plist>
EOF
}

# Create entitlements files
MAIN_ENTITLEMENTS="/tmp/main_entitlements.plist"
XPC_ENTITLEMENTS="/tmp/xpc_entitlements.plist"

create_entitlements "$MAIN_ENTITLEMENTS" "false"
create_entitlements "$XPC_ENTITLEMENTS" "true"

# ============================================================================
# Deep Code Signing with Hardened Runtime
# ============================================================================

log "Phase 1: Deep code signing with hardened runtime"

# Remove existing signatures and quarantine
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

# Function to sign a binary with hardened runtime
sign_binary() {
    local binary_path="$1"
    local entitlements="$2"
    local description="$3"
    
    if [ -f "$binary_path" ]; then
        log "Signing $description: $(basename "$binary_path")"
        codesign \
            --force \
            --sign "$SIGN_IDENTITY" \
            --options runtime \
            --entitlements "$entitlements" \
            --timestamp \
            "$binary_path"
    fi
}

# Function to sign an app bundle with hardened runtime
sign_app_bundle() {
    local app_path="$1"
    local entitlements="$2"
    local description="$3"
    
    if [ -d "$app_path" ]; then
        log "Signing $description: $(basename "$app_path")"
        codesign \
            --force \
            --sign "$SIGN_IDENTITY" \
            --options runtime \
            --entitlements "$entitlements" \
            --timestamp \
            "$app_path"
    fi
}

# 1. Sign all XPC Services first (most nested)
log "Signing XPC Services..."
find "$APP_BUNDLE" -name "*.xpc" -type d | while read xpc_service; do
    if [ -f "$xpc_service/Contents/MacOS/"* ]; then
        executable=$(find "$xpc_service/Contents/MacOS" -type f -perm +111 | head -1)
        if [ -n "$executable" ]; then
            sign_binary "$executable" "$XPC_ENTITLEMENTS" "XPC Service executable"
        fi
    fi
    sign_app_bundle "$xpc_service" "$XPC_ENTITLEMENTS" "XPC Service bundle"
done

# 2. Sign Sparkle framework components
log "Signing Sparkle framework components..."

SPARKLE_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    # Sign individual executables in Sparkle
    find "$SPARKLE_FRAMEWORK" -type f -perm +111 | grep -E "(Autoupdate|Updater|Downloader|Installer)" | while read executable; do
        sign_binary "$executable" "$MAIN_ENTITLEMENTS" "Sparkle executable"
    done
    
    # Sign nested app bundles in Sparkle
    find "$SPARKLE_FRAMEWORK" -name "*.app" -type d | while read app; do
        if [ -f "$app/Contents/MacOS/"* ]; then
            executable=$(find "$app/Contents/MacOS" -type f -perm +111 | head -1)
            if [ -n "$executable" ]; then
                sign_binary "$executable" "$MAIN_ENTITLEMENTS" "Sparkle app executable"
            fi
        fi
        sign_app_bundle "$app" "$MAIN_ENTITLEMENTS" "Sparkle app bundle"
    done
    
    # Sign the main Sparkle framework binary
    if [ -f "$SPARKLE_FRAMEWORK/Sparkle" ]; then
        sign_binary "$SPARKLE_FRAMEWORK/Sparkle" "$MAIN_ENTITLEMENTS" "Sparkle framework binary"
    fi
    
    # Sign the framework bundle
    log "Signing Sparkle framework bundle..."
    codesign \
        --force \
        --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp \
        "$SPARKLE_FRAMEWORK"
fi

# 3. Sign other frameworks
log "Signing other frameworks..."
find "$APP_BUNDLE/Contents/Frameworks" -name "*.framework" -not -path "*Sparkle*" -type d | while read framework; do
    framework_binary="$framework/$(basename "$framework" .framework)"
    if [ -f "$framework_binary" ]; then
        sign_binary "$framework_binary" "$MAIN_ENTITLEMENTS" "Framework binary"
    fi
    
    codesign \
        --force \
        --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp \
        "$framework"
done

# 4. Sign helper tools and executables
log "Signing helper tools..."
find "$APP_BUNDLE/Contents" -type f -perm +111 -not -path "*/MacOS/*" | while read executable; do
    sign_binary "$executable" "$MAIN_ENTITLEMENTS" "Helper executable"
done

# 5. Sign the main executable
log "Signing main executable..."
MAIN_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/CodeLooper"
if [ -f "$MAIN_EXECUTABLE" ]; then
    sign_binary "$MAIN_EXECUTABLE" "$MAIN_ENTITLEMENTS" "Main executable"
fi

# 6. Sign the main app bundle
log "Signing main app bundle..."
codesign \
    --force \
    --sign "$SIGN_IDENTITY" \
    --options runtime \
    --entitlements "$MAIN_ENTITLEMENTS" \
    --timestamp \
    "$APP_BUNDLE"

success "Code signing completed with hardened runtime"

# ============================================================================
# Verification
# ============================================================================

log "Phase 2: Verification"

# Verify signature
log "Verifying code signature..."
codesign --verify --deep --verbose "$APP_BUNDLE"
success "Code signature verification passed"

# Check Gatekeeper
log "Checking Gatekeeper assessment..."
spctl -a -t exec -vv "$APP_BUNDLE"
success "Gatekeeper assessment passed"

# ============================================================================
# Notarization
# ============================================================================

log "Phase 3: Notarization"

# Create zip for notarization
NOTARIZATION_ZIP="/tmp/CodeLooper_notarization.zip"
log "Creating notarization archive..."
ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARIZATION_ZIP"

# Submit for notarization
log "Submitting to Apple notary service..."
SUBMISSION_ID=$(xcrun notarytool submit "$NOTARIZATION_ZIP" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait \
    --output-format json | jq -r '.id')

if [ "$SUBMISSION_ID" = "null" ] || [ -z "$SUBMISSION_ID" ]; then
    error "Failed to get submission ID from notarization"
fi

log "Submission ID: $SUBMISSION_ID"

# Check notarization status
log "Checking notarization status..."
NOTARIZATION_STATUS=$(xcrun notarytool info "$SUBMISSION_ID" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --output-format json | jq -r '.status')

if [ "$NOTARIZATION_STATUS" = "Accepted" ]; then
    success "Notarization successful!"
    
    # Staple the ticket
    log "Stapling notarization ticket..."
    xcrun stapler staple "$APP_BUNDLE"
    success "Notarization ticket stapled"
    
    # Verify stapling
    log "Verifying stapled ticket..."
    xcrun stapler validate "$APP_BUNDLE"
    success "Stapled ticket verification passed"
    
else
    error "Notarization failed with status: $NOTARIZATION_STATUS"
    
    # Get detailed log
    log "Fetching notarization log..."
    xcrun notarytool log "$SUBMISSION_ID" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_PASSWORD" \
        --team-id "$APPLE_TEAM_ID"
    
    exit 1
fi

# ============================================================================
# Final Verification
# ============================================================================

log "Phase 4: Final verification"

# Test the notarized app
log "Testing notarized app with Gatekeeper..."
spctl -a -t exec -vv "$APP_BUNDLE"
success "Final Gatekeeper test passed"

# Check if ticket is properly stapled
xcrun stapler validate "$APP_BUNDLE"
success "Notarization ticket validation passed"

# ============================================================================
# Cleanup
# ============================================================================

log "Cleaning up temporary files..."
rm -f "$MAIN_ENTITLEMENTS" "$XPC_ENTITLEMENTS" "$NOTARIZATION_ZIP"

success "🎉 Complete notarization process finished successfully!"
success "The app is now fully notarized and ready for distribution"

log "App location: $APP_BUNDLE"
log "You can now distribute this app without Gatekeeper warnings"