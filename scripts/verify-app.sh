#!/bin/bash

# CodeLooper Application Verification Script
# Verifies app signing, notarization, and prerelease build flags

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[FAIL]${NC} $1"; }

# Header
echo -e "${BLUE}🔍 CodeLooper Application Verification${NC}"
echo "========================================="

# Get app path
APP_PATH="$1"
if [[ -z "$APP_PATH" ]]; then
    print_error "Usage: $0 <path-to-CodeLooper.app>"
    exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
    print_error "App not found at: $APP_PATH"
    exit 1
fi

print_info "Verifying app at: $APP_PATH"

# Status tracking
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Check 1: App structure
echo
print_info "Checking app structure..."

if [[ -f "$APP_PATH/Contents/Info.plist" ]]; then
    print_success "Info.plist found"
    ((PASSED_CHECKS++))
else
    print_error "Info.plist missing"
    ((FAILED_CHECKS++))
fi

if [[ -f "$APP_PATH/Contents/MacOS/CodeLooper" ]]; then
    print_success "Main executable found"
    ((PASSED_CHECKS++))
else
    print_error "Main executable missing"
    ((FAILED_CHECKS++))
fi

# Check 2: Version information
echo
print_info "Checking version information..."

if [[ -f "$APP_PATH/Contents/Info.plist" ]]; then
    BUNDLE_VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")
    BUILD_VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "")
    
    if [[ -n "$BUNDLE_VERSION" ]]; then
        print_success "Bundle version: $BUNDLE_VERSION"
        ((PASSED_CHECKS++))
    else
        print_error "Could not read bundle version"
        ((FAILED_CHECKS++))
    fi
    
    if [[ -n "$BUILD_VERSION" ]]; then
        print_success "Build version: $BUILD_VERSION"
        ((PASSED_CHECKS++))
    else
        print_error "Could not read build version"
        ((FAILED_CHECKS++))
    fi
    
    # Check for IS_PRERELEASE_BUILD flag
    PRERELEASE_FLAG=$(defaults read "$APP_PATH/Contents/Info.plist" IS_PRERELEASE_BUILD 2>/dev/null || echo "")
    if [[ -n "$PRERELEASE_FLAG" ]]; then
        if [[ "$PRERELEASE_FLAG" == "YES" || "$PRERELEASE_FLAG" == "1" ]]; then
            print_success "Pre-release build: YES"
            print_info "This is a beta/alpha/rc build"
        else
            print_success "Pre-release build: NO"
            print_info "This is a stable build"
        fi
        ((PASSED_CHECKS++))
    else
        print_warning "IS_PRERELEASE_BUILD flag not found"
        ((WARNING_CHECKS++))
    fi
fi

# Check 3: Code signing
echo
print_info "Checking code signing..."

if codesign -v "$APP_PATH" 2>/dev/null; then
    print_success "App is properly code signed"
    ((PASSED_CHECKS++))
    
    # Get signing details
    SIGNING_INFO=$(codesign -dv "$APP_PATH" 2>&1)
    if echo "$SIGNING_INFO" | grep -q "Developer ID"; then
        print_success "Signed with Developer ID (distribution ready)"
        ((PASSED_CHECKS++))
    elif echo "$SIGNING_INFO" | grep -q "Apple Development"; then
        print_warning "Signed with development certificate (not for distribution)"
        ((WARNING_CHECKS++))
    else
        print_warning "Unknown signing certificate type"
        ((WARNING_CHECKS++))
    fi
else
    print_error "App code signing verification failed"
    ((FAILED_CHECKS++))
fi

# Check hardened runtime
if codesign -dv "$APP_PATH" 2>&1 | grep -q "runtime"; then
    print_success "Hardened runtime enabled"
    ((PASSED_CHECKS++))
else
    print_warning "Hardened runtime not detected"
    ((WARNING_CHECKS++))
fi

# Check 4: Notarization
echo
print_info "Checking notarization..."

if spctl -a -v "$APP_PATH" 2>&1 | grep -q "accepted"; then
    print_success "App is notarized and accepted by Gatekeeper"
    ((PASSED_CHECKS++))
else
    print_warning "App may not be notarized or Gatekeeper check failed"
    print_info "This is normal for development builds"
    ((WARNING_CHECKS++))
fi

# Check 5: Sparkle framework
echo
print_info "Checking Sparkle framework..."

SPARKLE_PATH="$APP_PATH/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE_PATH" ]]; then
    print_success "Sparkle framework found"
    ((PASSED_CHECKS++))
    
    # Check Sparkle version
    if [[ -f "$SPARKLE_PATH/Resources/Info.plist" ]]; then
        SPARKLE_VERSION=$(defaults read "$SPARKLE_PATH/Resources/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
        print_success "Sparkle version: $SPARKLE_VERSION"
        ((PASSED_CHECKS++))
    fi
    
    # Check if Sparkle is properly signed
    if codesign -v "$SPARKLE_PATH" 2>/dev/null; then
        print_success "Sparkle framework is properly signed"
        ((PASSED_CHECKS++))
    else
        print_warning "Sparkle framework signing verification failed"
        ((WARNING_CHECKS++))
    fi
else
    print_error "Sparkle framework missing"
    ((FAILED_CHECKS++))
fi

# Check 6: Sparkle configuration
echo
print_info "Checking Sparkle configuration..."

if [[ -f "$APP_PATH/Contents/Info.plist" ]]; then
    FEED_URL=$(defaults read "$APP_PATH/Contents/Info.plist" SUFeedURL 2>/dev/null || echo "")
    PUBLIC_KEY=$(defaults read "$APP_PATH/Contents/Info.plist" SUPublicEDKey 2>/dev/null || echo "")
    
    if [[ -n "$FEED_URL" ]]; then
        print_success "Sparkle feed URL configured: $FEED_URL"
        ((PASSED_CHECKS++))
        
        # Check if URL is accessible
        if curl -sf "$FEED_URL" > /dev/null 2>&1; then
            print_success "Feed URL is accessible"
            ((PASSED_CHECKS++))
        else
            print_warning "Feed URL is not accessible (may not exist yet)"
            ((WARNING_CHECKS++))
        fi
    else
        print_error "Sparkle feed URL not configured"
        ((FAILED_CHECKS++))
    fi
    
    if [[ -n "$PUBLIC_KEY" ]]; then
        print_success "Sparkle public key configured"
        ((PASSED_CHECKS++))
    else
        print_error "Sparkle public key not configured"
        ((FAILED_CHECKS++))
    fi
fi

# Check 7: Bundle identifier
echo
print_info "Checking bundle identifier..."

if [[ -f "$APP_PATH/Contents/Info.plist" ]]; then
    BUNDLE_ID=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo "")
    
    if [[ -n "$BUNDLE_ID" ]]; then
        print_success "Bundle identifier: $BUNDLE_ID"
        ((PASSED_CHECKS++))
        
        if [[ "$BUNDLE_ID" == "me.steipete.codelooper" ]]; then
            print_success "Bundle identifier matches expected value"
            ((PASSED_CHECKS++))
        else
            print_warning "Bundle identifier differs from expected (me.steipete.codelooper)"
            ((WARNING_CHECKS++))
        fi
    else
        print_error "Could not read bundle identifier"
        ((FAILED_CHECKS++))
    fi
fi

# Check 8: File permissions
echo
print_info "Checking file permissions..."

if [[ -x "$APP_PATH/Contents/MacOS/CodeLooper" ]]; then
    print_success "Main executable has execute permissions"
    ((PASSED_CHECKS++))
else
    print_error "Main executable is not executable"
    ((FAILED_CHECKS++))
fi

# Summary
echo
echo "========================================="
print_info "Verification Summary:"
echo -e "  ${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "  ${RED}Failed: $FAILED_CHECKS${NC}"
echo -e "  ${YELLOW}Warnings: $WARNING_CHECKS${NC}"

echo
if [[ $FAILED_CHECKS -gt 0 ]]; then
    print_error "❌ App verification FAILED. Critical issues found."
    exit 1
elif [[ $WARNING_CHECKS -gt 0 ]]; then
    print_warning "⚠️  App verification PASSED with warnings."
    print_info "Review the warnings above before distribution."
    exit 0
else
    print_success "✅ App verification PASSED. Ready for distribution!"
    exit 0
fi