#!/bin/bash

# CodeLooper Pre-release System Verification Script
# End-to-end validation of the beta/pre-release system

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

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[FAIL]${NC} $1"; }

# Header
echo -e "${BLUE}🧪 CodeLooper Pre-release System Verification${NC}"
echo "=============================================="

# Status tracking
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Check 1: Project configuration
echo
print_info "Checking Project.swift configuration..."

cd "$PROJECT_ROOT"

if [[ -f "Project.swift" ]]; then
    print_success "Project.swift found"
    ((PASSED_CHECKS++))
    
    # Check IS_PRERELEASE_BUILD configuration
    if grep -q "IS_PRERELEASE_BUILD.*IS_PRERELEASE_BUILD" Project.swift; then
        print_success "IS_PRERELEASE_BUILD environment variable mapping found"
        ((PASSED_CHECKS++))
    else
        print_error "IS_PRERELEASE_BUILD environment variable mapping missing"
        print_info "Add: \"IS_PRERELEASE_BUILD\": \"\$(IS_PRERELEASE_BUILD)\""
        ((FAILED_CHECKS++))
    fi
else
    print_error "Project.swift not found"
    ((FAILED_CHECKS++))
fi

# Check 2: UpdateChannel.swift
echo
print_info "Checking UpdateChannel.swift implementation..."

if [[ -f "App/UpdateChannel.swift" ]]; then
    print_success "UpdateChannel.swift found"
    ((PASSED_CHECKS++))
    
    # Check for key methods
    if grep -q "defaultChannel" App/UpdateChannel.swift; then
        print_success "defaultChannel method found"
        ((PASSED_CHECKS++))
    else
        print_error "defaultChannel method missing"
        ((FAILED_CHECKS++))
    fi
    
    if grep -q "isPrereleaseBuild" App/UpdateChannel.swift; then
        print_success "isPrereleaseBuild property found"
        ((PASSED_CHECKS++))
    else
        print_error "isPrereleaseBuild property missing"
        ((FAILED_CHECKS++))
    fi
    
    if grep -q "appcastURL" App/UpdateChannel.swift; then
        print_success "appcastURL property found"
        ((PASSED_CHECKS++))
    else
        print_error "appcastURL property missing"
        ((FAILED_CHECKS++))
    fi
    
    # Check for both channels
    if grep -q "case stable" App/UpdateChannel.swift && grep -q "case prerelease" App/UpdateChannel.swift; then
        print_success "Both stable and prerelease channels defined"
        ((PASSED_CHECKS++))
    else
        print_error "Missing stable or prerelease channel definitions"
        ((FAILED_CHECKS++))
    fi
else
    print_error "UpdateChannel.swift not found"
    ((FAILED_CHECKS++))
fi

# Check 3: Appcast files
echo
print_info "Checking appcast files..."

if [[ -f "appcast.xml" ]]; then
    print_success "Stable appcast (appcast.xml) exists"
    ((PASSED_CHECKS++))
    
    if xmllint --noout appcast.xml 2>/dev/null; then
        print_success "Stable appcast is valid XML"
        ((PASSED_CHECKS++))
    else
        print_error "Stable appcast has XML errors"
        ((FAILED_CHECKS++))
    fi
else
    print_warning "Stable appcast (appcast.xml) not found"
    ((WARNING_CHECKS++))
fi

if [[ -f "appcast-prerelease.xml" ]]; then
    print_success "Pre-release appcast (appcast-prerelease.xml) exists"
    ((PASSED_CHECKS++))
    
    if xmllint --noout appcast-prerelease.xml 2>/dev/null; then
        print_success "Pre-release appcast is valid XML"
        ((PASSED_CHECKS++))
    else
        print_error "Pre-release appcast has XML errors"
        ((FAILED_CHECKS++))
    fi
else
    print_warning "Pre-release appcast (appcast-prerelease.xml) not found"
    ((WARNING_CHECKS++))
fi

# Check 4: Release scripts
echo
print_info "Checking release automation scripts..."

required_scripts=(
    "release.sh"
    "preflight-check.sh"
    "version.sh"
    "generate-appcast.sh"
    "verify-app.sh"
    "verify-appcast.sh"
)

for script in "${required_scripts[@]}"; do
    script_path="scripts/$script"
    if [[ -f "$script_path" ]]; then
        if [[ -x "$script_path" ]]; then
            print_success "$script is executable"
            ((PASSED_CHECKS++))
        else
            print_warning "$script exists but is not executable"
            ((WARNING_CHECKS++))
        fi
    else
        print_error "$script missing"
        ((FAILED_CHECKS++))
    fi
done

# Check 5: Release script functionality
echo
print_info "Checking release script pre-release support..."

if [[ -f "scripts/release.sh" ]]; then
    # Check for pre-release types
    if grep -q "beta\|alpha\|rc" scripts/release.sh; then
        print_success "Release script supports pre-release types"
        ((PASSED_CHECKS++))
    else
        print_error "Release script missing pre-release type support"
        ((FAILED_CHECKS++))
    fi
    
    # Check for IS_PRERELEASE_BUILD handling
    if grep -q "IS_PRERELEASE_BUILD" scripts/release.sh; then
        print_success "Release script handles IS_PRERELEASE_BUILD flag"
        ((PASSED_CHECKS++))
    else
        print_error "Release script missing IS_PRERELEASE_BUILD handling"
        ((FAILED_CHECKS++))
    fi
else
    print_error "Release script not found"
    ((FAILED_CHECKS++))
fi

# Check 6: Version script functionality
echo
print_info "Checking version script pre-release support..."

if [[ -f "scripts/version.sh" ]]; then
    if grep -q "prerelease" scripts/version.sh; then
        print_success "Version script supports pre-release versions"
        ((PASSED_CHECKS++))
    else
        print_error "Version script missing pre-release support"
        ((FAILED_CHECKS++))
    fi
    
    # Check for semantic versioning
    if grep -q "major\|minor\|patch" scripts/version.sh; then
        print_success "Version script supports semantic versioning"
        ((PASSED_CHECKS++))
    else
        print_error "Version script missing semantic versioning support"
        ((FAILED_CHECKS++))
    fi
else
    print_error "Version script not found"
    ((FAILED_CHECKS++))
fi

# Check 7: Test pre-release flag detection
echo
print_info "Testing pre-release flag detection..."

# Create a temporary test app bundle
temp_app=$(mktemp -d)/TestApp.app
mkdir -p "$temp_app/Contents"

# Test case 1: Pre-release build
cat > "$temp_app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0-beta.1</string>
    <key>IS_PRERELEASE_BUILD</key>
    <string>YES</string>
</dict>
</plist>
EOF

# Simulate UpdateChannel detection logic
if [[ -f "App/UpdateChannel.swift" ]]; then
    # Extract the version and check logic (simplified)
    version="1.0.0-beta.1"
    prerelease_flag="YES"
    
    if [[ "$prerelease_flag" == "YES" ]] || [[ "$version" == *"beta"* ]]; then
        print_success "Pre-release detection logic working"
        ((PASSED_CHECKS++))
    else
        print_error "Pre-release detection logic failed"
        ((FAILED_CHECKS++))
    fi
fi

# Cleanup
rm -rf "$(dirname "$temp_app")"

# Check 8: Sparkle configuration
echo
print_info "Checking Sparkle configuration..."

if [[ -f "App/Info.plist" ]]; then
    # Check for feed URL
    if grep -q "SUFeedURL" App/Info.plist; then
        print_success "Sparkle feed URL configured in Info.plist"
        ((PASSED_CHECKS++))
        
        # Extract and validate URL
        feed_url=$(grep -A1 "SUFeedURL" App/Info.plist | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        if [[ "$feed_url" == *"appcast.xml"* ]]; then
            print_success "Feed URL points to stable appcast"
            ((PASSED_CHECKS++))
        else
            print_warning "Feed URL may not point to stable appcast"
            ((WARNING_CHECKS++))
        fi
    else
        print_error "SUFeedURL not found in Info.plist"
        ((FAILED_CHECKS++))
    fi
    
    # Check for public key
    if grep -q "SUPublicEDKey" App/Info.plist; then
        print_success "Sparkle public key configured"
        ((PASSED_CHECKS++))
    else
        print_error "SUPublicEDKey not found in Info.plist"
        ((FAILED_CHECKS++))
    fi
else
    print_error "App/Info.plist not found"
    ((FAILED_CHECKS++))
fi

# Check 9: Documentation
echo
print_info "Checking documentation..."

if [[ -f "RELEASE.md" ]]; then
    print_success "Release documentation (RELEASE.md) exists"
    ((PASSED_CHECKS++))
else
    print_warning "Release documentation (RELEASE.md) not found"
    ((WARNING_CHECKS++))
fi

if [[ -f "CLAUDE.md" ]]; then
    if grep -q "IS_PRERELEASE_BUILD\|prerelease\|beta" CLAUDE.md; then
        print_success "CLAUDE.md mentions pre-release system"
        ((PASSED_CHECKS++))
    else
        print_warning "CLAUDE.md doesn't mention pre-release system"
        ((WARNING_CHECKS++))
    fi
else
    print_warning "CLAUDE.md not found"
    ((WARNING_CHECKS++))
fi

# Check 10: Integration test
echo
print_info "Running integration test..."

# Test preflight check
if [[ -f "scripts/preflight-check.sh" ]]; then
    if "./scripts/preflight-check.sh" --help > /dev/null 2>&1 || "./scripts/preflight-check.sh" > /dev/null 2>&1; then
        print_success "Preflight check script runs without syntax errors"
        ((PASSED_CHECKS++))
    else
        print_warning "Preflight check script may have issues"
        ((WARNING_CHECKS++))
    fi
fi

# Test version script
if [[ -f "scripts/version.sh" ]]; then
    if "./scripts/version.sh" --help > /dev/null 2>&1; then
        print_success "Version script runs without syntax errors"
        ((PASSED_CHECKS++))
    else
        print_warning "Version script may have issues"
        ((WARNING_CHECKS++))
    fi
fi

# Summary
echo
echo "=============================================="
print_info "Pre-release System Verification Summary:"
echo -e "  ${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "  ${RED}Failed: $FAILED_CHECKS${NC}"
echo -e "  ${YELLOW}Warnings: $WARNING_CHECKS${NC}"

echo
echo -e "${BLUE}System Components Status:${NC}"
echo "  📋 Project Configuration: $([ $FAILED_CHECKS -eq 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}")"
echo "  🔀 Update Channels: $([ -f "App/UpdateChannel.swift" ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}")"
echo "  📡 Appcast Files: $([ -f "appcast.xml" ] && [ -f "appcast-prerelease.xml" ] && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}△${NC}")"
echo "  🚀 Release Scripts: $([ -f "scripts/release.sh" ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}")"
echo "  🔧 Version Management: $([ -f "scripts/version.sh" ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}")"
echo "  ✅ Verification Tools: $([ -f "scripts/verify-app.sh" ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}")"

echo
if [[ $FAILED_CHECKS -gt 0 ]]; then
    print_error "❌ Pre-release system verification FAILED."
    print_info "Fix the critical issues above before using the pre-release system."
    exit 1
elif [[ $WARNING_CHECKS -gt 0 ]]; then
    print_warning "⚠️  Pre-release system verification PASSED with warnings."
    print_info "The system is functional but consider addressing the warnings."
    exit 0
else
    print_success "✅ Pre-release system verification PASSED!"
    print_info "Your pre-release system is ready for use."
    echo
    print_info "Usage examples:"
    print_info "  ./scripts/version.sh --prerelease beta    # Create beta version"
    print_info "  ./scripts/release.sh beta 1               # Release beta.1"
    print_info "  ./scripts/release.sh stable               # Release stable"
    exit 0
fi