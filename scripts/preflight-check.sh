#!/bin/bash

# CodeLooper Pre-flight Check Script
# Validates release readiness before starting the build process
# Adapted from VibeMeter's comprehensive validation approach

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Status tracking
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_pass() { 
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_CHECKS++))
}
print_fail() { 
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_CHECKS++))
}
print_warning() { 
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNING_CHECKS++))
}

# Header
echo -e "${BLUE}🔍 CodeLooper Pre-flight Release Validation${NC}"
echo "=============================================="

# Check 1: Git Repository Status
echo
print_info "Checking Git repository status..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_fail "Not in a Git repository"
else
    print_pass "In Git repository"
fi

# Check for clean working directory
if [[ -n "$(git status --porcelain)" ]]; then
    print_fail "Working directory is not clean. Please commit or stash changes."
    git status --short
else
    print_pass "Working directory is clean"
fi

# Check current branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" != "main" ]]; then
    print_warning "Not on main branch (currently on: $current_branch)"
else
    print_pass "On main branch"
fi

# Check if we're synced with remote
if git fetch origin; then
    local_commit=$(git rev-parse HEAD)
    remote_commit=$(git rev-parse origin/main)
    if [[ "$local_commit" != "$remote_commit" ]]; then
        print_fail "Local branch is not synced with origin/main"
    else
        print_pass "Synced with remote origin/main"
    fi
else
    print_warning "Could not fetch from origin"
fi

# Check 2: Required Tools
echo
print_info "Checking required development tools..."

# Required tools
required_tools=(
    "gh:GitHub CLI"
    "jq:JSON processor"
    "xcodebuild:Xcode command line tools"
    "tuist:Tuist project generator"
    "xcbeautify:Xcode output formatter"
)

for tool_info in "${required_tools[@]}"; do
    tool="${tool_info%%:*}"
    description="${tool_info##*:}"
    
    if command -v "$tool" &> /dev/null; then
        print_pass "$description ($tool) is available"
    else
        print_fail "$description ($tool) is not installed"
        case "$tool" in
            "gh")
                print_info "Install with: brew install gh"
                ;;
            "jq")
                print_info "Install with: brew install jq"
                ;;
            "tuist")
                print_info "Install with: curl -Ls https://install.tuist.io | bash"
                ;;
            "xcbeautify")
                print_info "Install with: brew install xcbeautify"
                ;;
        esac
    fi
done

# Check 3: Version Information
echo
print_info "Checking version information..."

cd "$PROJECT_ROOT"

# Check if Project.swift exists
if [[ ! -f "Project.swift" ]]; then
    print_fail "Project.swift not found"
else
    print_pass "Project.swift found"
    
    # Extract version information
    if marketing_version=$(grep "MARKETING_VERSION" Project.swift | head -1 | sed 's/.*"\(.*\)".*/\1/'); then
        if [[ -n "$marketing_version" ]]; then
            print_pass "Marketing version: $marketing_version"
        else
            print_fail "Could not extract marketing version from Project.swift"
        fi
    else
        print_fail "Marketing version not found in Project.swift"
    fi
    
    if build_version=$(grep "CURRENT_PROJECT_VERSION" Project.swift | head -1 | sed 's/.*"\(.*\)".*/\1/'); then
        if [[ -n "$build_version" ]]; then
            print_pass "Build version: $build_version"
        else
            print_fail "Could not extract build version from Project.swift"
        fi
    else
        print_fail "Build version not found in Project.swift"
    fi
    
    # Check for IS_PRERELEASE_BUILD configuration
    if grep -q "IS_PRERELEASE_BUILD" Project.swift; then
        print_pass "IS_PRERELEASE_BUILD configuration found"
    else
        print_fail "IS_PRERELEASE_BUILD configuration missing from Project.swift"
    fi
fi

# Check 4: Code Signing Configuration
echo
print_info "Checking code signing configuration..."

# Check for Developer ID certificates
if security find-identity -v -p codesigning | grep -q "Apple Development\|Apple Distribution\|Developer ID"; then
    print_pass "Code signing certificates found"
    
    # List available certificates
    echo "Available certificates:"
    security find-identity -v -p codesigning | grep "Apple Development\|Apple Distribution\|Developer ID" | sed 's/^/  /'
else
    print_fail "No valid code signing certificates found"
fi

# Check for notarization credentials (environment variables)
if [[ -n "$APPLE_ID" ]] && [[ -n "$APPLE_PASSWORD" ]]; then
    print_pass "Notarization credentials available (environment variables)"
elif [[ -n "$APPLE_ID" ]] && [[ -n "$APPLE_PASSWORD_KEYCHAIN" ]]; then
    print_pass "Notarization credentials available (keychain)"
else
    print_warning "Notarization credentials not configured"
    print_info "Set APPLE_ID and APPLE_PASSWORD (or APPLE_PASSWORD_KEYCHAIN) environment variables"
fi

# Check 5: Sparkle Configuration
echo
print_info "Checking Sparkle update configuration..."

# Check for Sparkle tools
sparkle_tools=("sign_update" "generate_appcast")
for tool in "${sparkle_tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        print_pass "Sparkle tool: $tool"
    else
        print_warning "Sparkle tool not found: $tool"
        print_info "Install Sparkle tools from: https://github.com/sparkle-project/Sparkle"
    fi
done

# Check for appcast files
if [[ -f "appcast.xml" ]]; then
    print_pass "Main appcast.xml exists"
    
    # Validate XML
    if xmllint --noout "appcast.xml" 2>/dev/null; then
        print_pass "appcast.xml is valid XML"
    else
        print_fail "appcast.xml is not valid XML"
    fi
else
    print_warning "appcast.xml not found (will be created during release)"
fi

if [[ -f "appcast-prerelease.xml" ]]; then
    print_pass "Pre-release appcast exists"
    
    # Validate XML
    if xmllint --noout "appcast-prerelease.xml" 2>/dev/null; then
        print_pass "appcast-prerelease.xml is valid XML"
    else
        print_fail "appcast-prerelease.xml is not valid XML"
    fi
else
    print_warning "appcast-prerelease.xml not found (will be created during release)"
fi

# Check Info.plist Sparkle configuration
if [[ -f "App/Info.plist" ]]; then
    if /usr/libexec/PlistBuddy -c "Print :SUFeedURL" "App/Info.plist" &>/dev/null; then
        feed_url=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "App/Info.plist")
        print_pass "Sparkle feed URL configured: $feed_url"
    else
        print_fail "SUFeedURL not configured in Info.plist"
    fi
    
    if /usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "App/Info.plist" &>/dev/null; then
        print_pass "Sparkle public key configured"
    else
        print_fail "SUPublicEDKey not configured in Info.plist"
    fi
else
    print_fail "App/Info.plist not found"
fi

# Check 6: Build Number Validation
echo
print_info "Checking build number uniqueness..."

if [[ -n "$build_version" ]]; then
    # Check if build number already exists in GitHub releases
    if command -v gh &> /dev/null; then
        if gh release list --repo steipete/CodeLooper --limit 100 2>/dev/null | grep -q "$build_version"; then
            print_fail "Build number $build_version already exists in GitHub releases"
        else
            print_pass "Build number $build_version is unique"
        fi
    else
        print_warning "Cannot verify build number uniqueness (gh not available)"
    fi
    
    # Check appcast files for duplicate build numbers
    for appcast in "appcast.xml" "appcast-prerelease.xml"; do
        if [[ -f "$appcast" ]] && grep -q "sparkle:version=\"$build_version\"" "$appcast"; then
            print_fail "Build number $build_version already exists in $appcast"
        fi
    done
fi

# Check 7: Network Connectivity
echo
print_info "Checking network connectivity..."

if ping -c 1 github.com &>/dev/null; then
    print_pass "GitHub connectivity available"
else
    print_warning "Cannot reach GitHub"
fi

if ping -c 1 raw.githubusercontent.com &>/dev/null; then
    print_pass "GitHub raw content connectivity available"
else
    print_warning "Cannot reach GitHub raw content (appcast hosting)"
fi

# Summary
echo
echo "=============================================="
print_info "Pre-flight check summary:"
echo -e "  ${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "  ${RED}Failed: $FAILED_CHECKS${NC}"
echo -e "  ${YELLOW}Warnings: $WARNING_CHECKS${NC}"

if [[ $FAILED_CHECKS -gt 0 ]]; then
    echo
    print_fail "❌ Pre-flight check FAILED. Please fix the issues above before releasing."
    exit 1
else
    echo
    print_pass "✅ Pre-flight check PASSED. Ready for release!"
    
    if [[ $WARNING_CHECKS -gt 0 ]]; then
        print_warning "Note: There are $WARNING_CHECKS warnings. Review them before proceeding."
    fi
    
    exit 0
fi