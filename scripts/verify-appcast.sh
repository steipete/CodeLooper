#!/bin/bash

# CodeLooper Appcast Verification Script
# Validates appcast XML files for both stable and pre-release channels

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
echo -e "${BLUE}📡 CodeLooper Appcast Verification${NC}"
echo "===================================="

# Status tracking
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Verify XML file
verify_xml_file() {
    local file="$1"
    local description="$2"
    
    echo
    print_info "Verifying $description ($file)..."
    
    if [[ ! -f "$file" ]]; then
        print_error "$description not found at $file"
        ((FAILED_CHECKS++))
        return 1
    fi
    
    print_success "$description exists"
    ((PASSED_CHECKS++))
    
    # Check XML validity
    if xmllint --noout "$file" 2>/dev/null; then
        print_success "$description is valid XML"
        ((PASSED_CHECKS++))
    else
        print_error "$description has XML validation errors"
        ((FAILED_CHECKS++))
        return 1
    fi
    
    # Check required elements
    if grep -q "<rss" "$file"; then
        print_success "RSS root element found"
        ((PASSED_CHECKS++))
    else
        print_error "RSS root element missing"
        ((FAILED_CHECKS++))
    fi
    
    if grep -q "xmlns:sparkle" "$file"; then
        print_success "Sparkle namespace declared"
        ((PASSED_CHECKS++))
    else
        print_error "Sparkle namespace missing"
        ((FAILED_CHECKS++))
    fi
    
    if grep -q "<title>" "$file"; then
        local title=$(grep "<title>" "$file" | head -1 | sed 's/.*<title>\(.*\)<\/title>.*/\1/')
        print_success "Channel title: $title"
        ((PASSED_CHECKS++))
    else
        print_error "Channel title missing"
        ((FAILED_CHECKS++))
    fi
    
    if grep -q "<link>" "$file"; then
        local link=$(grep "<link>" "$file" | head -1 | sed 's/.*<link>\(.*\)<\/link>.*/\1/')
        print_success "Channel link: $link"
        ((PASSED_CHECKS++))
    else
        print_error "Channel link missing"
        ((FAILED_CHECKS++))
    fi
    
    # Count items
    local item_count=$(grep -c "<item>" "$file" || echo "0")
    if [[ $item_count -gt 0 ]]; then
        print_success "Contains $item_count release(s)"
        ((PASSED_CHECKS++))
    else
        print_warning "No release items found"
        ((WARNING_CHECKS++))
    fi
    
    # Check item structure
    if [[ $item_count -gt 0 ]]; then
        if grep -q "sparkle:version" "$file"; then
            print_success "Sparkle version attributes found"
            ((PASSED_CHECKS++))
        else
            print_error "Sparkle version attributes missing"
            ((FAILED_CHECKS++))
        fi
        
        if grep -q "sparkle:shortVersionString" "$file"; then
            print_success "Sparkle short version strings found"
            ((PASSED_CHECKS++))
        else
            print_error "Sparkle short version strings missing"
            ((FAILED_CHECKS++))
        fi
        
        if grep -q "enclosure" "$file"; then
            print_success "Enclosure elements found"
            ((PASSED_CHECKS++))
        else
            print_error "Enclosure elements missing"
            ((FAILED_CHECKS++))
        fi
        
        if grep -q "sparkle:edSignature" "$file"; then
            local sig_count=$(grep -c "sparkle:edSignature" "$file")
            local placeholder_count=$(grep -c "SIGNATURE_PLACEHOLDER" "$file")
            
            if [[ $placeholder_count -gt 0 ]]; then
                print_warning "$placeholder_count item(s) have placeholder signatures"
                ((WARNING_CHECKS++))
            fi
            
            local real_sig_count=$((sig_count - placeholder_count))
            if [[ $real_sig_count -gt 0 ]]; then
                print_success "$real_sig_count item(s) have real EdDSA signatures"
                ((PASSED_CHECKS++))
            fi
        else
            print_error "EdDSA signatures missing"
            ((FAILED_CHECKS++))
        fi
    fi
    
    return 0
}

# Verify URL accessibility
verify_url_accessibility() {
    local url="$1"
    local description="$2"
    
    if curl -sf "$url" > /dev/null 2>&1; then
        print_success "$description is accessible"
        ((PASSED_CHECKS++))
    else
        print_warning "$description is not accessible"
        print_info "This is normal if the appcast hasn't been published yet"
        ((WARNING_CHECKS++))
    fi
}

# Check download URLs
verify_download_urls() {
    local file="$1"
    local description="$2"
    
    if [[ ! -f "$file" ]]; then
        return
    fi
    
    echo
    print_info "Checking download URLs in $description..."
    
    local urls
    urls=$(grep -o 'url="[^"]*"' "$file" | sed 's/url="//; s/"//' | grep -v "^$")
    
    if [[ -z "$urls" ]]; then
        print_warning "No download URLs found in $description"
        ((WARNING_CHECKS++))
        return
    fi
    
    local url_count=0
    local accessible_count=0
    
    while IFS= read -r url; do
        if [[ -n "$url" ]]; then
            ((url_count++))
            print_info "Checking: $url"
            
            if curl -sf --head "$url" > /dev/null 2>&1; then
                print_success "✓ Accessible"
                ((accessible_count++))
            else
                print_warning "✗ Not accessible"
            fi
        fi
    done <<< "$urls"
    
    if [[ $accessible_count -eq $url_count ]]; then
        print_success "All $url_count download URLs are accessible"
        ((PASSED_CHECKS++))
    elif [[ $accessible_count -gt 0 ]]; then
        print_warning "$accessible_count of $url_count download URLs are accessible"
        ((WARNING_CHECKS++))
    else
        print_warning "None of the $url_count download URLs are accessible"
        ((WARNING_CHECKS++))
    fi
}

# Main verification
cd "$PROJECT_ROOT"

# Verify stable appcast
verify_xml_file "appcast.xml" "Stable appcast"

# Verify pre-release appcast
verify_xml_file "appcast-prerelease.xml" "Pre-release appcast"

# Check URL accessibility
echo
print_info "Checking appcast URL accessibility..."

STABLE_URL="https://raw.githubusercontent.com/steipete/CodeLooper/main/appcast.xml"
PRERELEASE_URL="https://raw.githubusercontent.com/steipete/CodeLooper/main/appcast-prerelease.xml"

verify_url_accessibility "$STABLE_URL" "Stable appcast URL"
verify_url_accessibility "$PRERELEASE_URL" "Pre-release appcast URL"

# Verify download URLs
verify_download_urls "appcast.xml" "stable appcast"
verify_download_urls "appcast-prerelease.xml" "pre-release appcast"

# Compare appcast contents
echo
print_info "Comparing appcast contents..."

if [[ -f "appcast.xml" ]] && [[ -f "appcast-prerelease.xml" ]]; then
    local stable_items=$(grep -c "<item>" appcast.xml || echo "0")
    local prerelease_items=$(grep -c "<item>" appcast-prerelease.xml || echo "0")
    
    if [[ $prerelease_items -ge $stable_items ]]; then
        print_success "Pre-release appcast has $prerelease_items items (stable has $stable_items)"
        print_info "Pre-release channel correctly includes all releases"
        ((PASSED_CHECKS++))
    else
        print_error "Pre-release appcast has fewer items than stable appcast"
        print_error "Expected: pre-release >= stable, Got: $prerelease_items < $stable_items"
        ((FAILED_CHECKS++))
    fi
fi

# Check for version conflicts
echo
print_info "Checking for version conflicts..."

for appcast in "appcast.xml" "appcast-prerelease.xml"; do
    if [[ -f "$appcast" ]]; then
        local build_numbers
        build_numbers=$(grep -o 'sparkle:version="[^"]*"' "$appcast" | sed 's/sparkle:version="//; s/"//' | sort -n)
        
        local unique_builds
        unique_builds=$(echo "$build_numbers" | sort -u)
        
        if [[ "$build_numbers" == "$unique_builds" ]]; then
            local count=$(echo "$build_numbers" | wc -w)
            print_success "$appcast has unique build numbers ($count total)"
            ((PASSED_CHECKS++))
        else
            print_error "$appcast has duplicate build numbers"
            ((FAILED_CHECKS++))
        fi
    fi
done

# Summary
echo
echo "===================================="
print_info "Verification Summary:"
echo -e "  ${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "  ${RED}Failed: $FAILED_CHECKS${NC}"
echo -e "  ${YELLOW}Warnings: $WARNING_CHECKS${NC}"

echo
if [[ $FAILED_CHECKS -gt 0 ]]; then
    print_error "❌ Appcast verification FAILED. Critical issues found."
    exit 1
elif [[ $WARNING_CHECKS -gt 0 ]]; then
    print_warning "⚠️  Appcast verification PASSED with warnings."
    print_info "Review the warnings above before publishing."
    exit 0
else
    print_success "✅ Appcast verification PASSED. Ready for publishing!"
    exit 0
fi