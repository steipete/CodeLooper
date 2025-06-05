#!/bin/bash

# CodeLooper Appcast Generation Script
# Generates dual-channel appcast files with GitHub integration and signature caching
# Adapted from VibeMeter's sophisticated appcast generation approach

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SIGNATURES_CACHE="$PROJECT_ROOT/signatures_cache.txt"

# GitHub configuration
GITHUB_USERNAME="${GITHUB_USERNAME:-steipete}"
GITHUB_REPO="${GITHUB_REPO:-CodeLooper}"
GITHUB_REPO_FULL="$GITHUB_USERNAME/$GITHUB_REPO"

# Sparkle configuration
SPARKLE_PRIVATE_KEY_PATH="${SPARKLE_PRIVATE_KEY_PATH:-$HOME/.sparkle_private_key}"
KEYCHAIN_KEY_NAME="${KEYCHAIN_KEY_NAME:-CodeLooper-Sparkle-Private-Key}"

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Header
echo -e "${BLUE}📡 CodeLooper Appcast Generator${NC}"
echo "======================================="

# Check required tools
check_required_tools() {
    local tools=("gh" "jq")
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "Required tool '$tool' is not installed"
            case "$tool" in
                "gh")
                    print_info "Install with: brew install gh"
                    ;;
                "jq")
                    print_info "Install with: brew install jq"
                    ;;
            esac
            exit 1
        fi
    done
}

# Load signature from cache
get_cached_signature() {
    local filename="$1"
    
    if [[ -f "$SIGNATURES_CACHE" ]]; then
        grep "^$filename:" "$SIGNATURES_CACHE" 2>/dev/null | cut -d':' -f2 || true
    fi
}

# Save signature to cache
cache_signature() {
    local filename="$1"
    local signature="$2"
    
    # Remove existing entry
    if [[ -f "$SIGNATURES_CACHE" ]]; then
        grep -v "^$filename:" "$SIGNATURES_CACHE" > "$SIGNATURES_CACHE.tmp" 2>/dev/null || true
        mv "$SIGNATURES_CACHE.tmp" "$SIGNATURES_CACHE" 2>/dev/null || true
    fi
    
    # Add new entry
    echo "$filename:$signature" >> "$SIGNATURES_CACHE"
    print_info "Cached signature for $filename"
}

# Generate EdDSA signature for file
generate_signature() {
    local file_url="$1"
    local filename="$(basename "$file_url")"
    
    # Check cache first
    local cached_signature
    cached_signature=$(get_cached_signature "$filename")
    if [[ -n "$cached_signature" ]]; then
        print_info "Using cached signature for $filename"
        echo "$cached_signature"
        return
    fi
    
    print_info "Generating signature for $filename..."
    
    # Try multiple signing methods
    local signature=""
    
    # Method 1: Try keychain-based signing
    if command -v security &> /dev/null; then
        if security find-generic-password -s "$KEYCHAIN_KEY_NAME" &>/dev/null; then
            print_info "Attempting keychain-based signing..."
            local temp_key="/tmp/sparkle_private_key_$$"
            
            if security find-generic-password -s "$KEYCHAIN_KEY_NAME" -w > "$temp_key" 2>/dev/null; then
                if signature=$(curl -sL "$file_url" | sign_update - "$temp_key" 2>/dev/null); then
                    rm -f "$temp_key"
                    print_success "Generated signature using keychain key"
                    cache_signature "$filename" "$signature"
                    echo "$signature"
                    return
                fi
                rm -f "$temp_key"
            fi
        fi
    fi
    
    # Method 2: Try private key file
    if [[ -f "$SPARKLE_PRIVATE_KEY_PATH" ]] && command -v sign_update &> /dev/null; then
        print_info "Attempting file-based signing..."
        if signature=$(curl -sL "$file_url" | sign_update - "$SPARKLE_PRIVATE_KEY_PATH" 2>/dev/null); then
            print_success "Generated signature using private key file"
            cache_signature "$filename" "$signature"
            echo "$signature"
            return
        fi
    fi
    
    # Method 3: Try bundled Sparkle tools
    if command -v /Applications/Sparkle.app/Contents/MacOS/sign_update &> /dev/null && [[ -f "$SPARKLE_PRIVATE_KEY_PATH" ]]; then
        print_info "Attempting bundled Sparkle tool..."
        if signature=$(curl -sL "$file_url" | /Applications/Sparkle.app/Contents/MacOS/sign_update - "$SPARKLE_PRIVATE_KEY_PATH" 2>/dev/null); then
            print_success "Generated signature using bundled Sparkle tool"
            cache_signature "$filename" "$signature"
            echo "$signature"
            return
        fi
    fi
    
    print_warning "Could not generate signature for $filename"
    echo "SIGNATURE_PLACEHOLDER"
}

# Get file size from URL
get_file_size() {
    local url="$1"
    local size
    
    # Try to get size from HTTP headers
    if size=$(curl -sI "$url" | grep -i content-length | awk '{print $2}' | tr -d '\r'); then
        if [[ -n "$size" && "$size" =~ ^[0-9]+$ ]]; then
            echo "$size"
            return
        fi
    fi
    
    print_warning "Could not determine file size for $url"
    echo "0"
}

# Extract build number from DMG (simplified version)
extract_build_number() {
    local version="$1"
    local asset_name="$2"
    
    # Try to extract from asset name (format: CodeLooper-version-build.dmg)
    if [[ "$asset_name" =~ CodeLooper-[^-]+-([0-9]+)\.dmg ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi
    
    # Fallback: use a simple counter based on version components
    local major minor patch
    if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[3]}"
        echo $((major * 1000 + minor * 100 + patch))
    else
        echo "1"
    fi
}

# Generate appcast XML content
generate_appcast_content() {
    local title="$1"
    local releases_json="$2"
    local include_prereleases="$3"
    
    cat << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>$title</title>
        <link>https://github.com/$GITHUB_REPO_FULL</link>
        <description>CodeLooper automatic updates feed</description>
        <language>en</language>
        
EOF

    # Process releases
    local jq_filter
    if [[ "$include_prereleases" == "false" ]]; then
        jq_filter="map(select(.prerelease == false))"
    else
        jq_filter="."
    fi
    
    # Use jq -c for compact single-line output and proper array iteration
    local filtered_releases
    filtered_releases=$(echo "$releases_json" | jq -c "$jq_filter")
    
    # Get array length for iteration
    local release_count
    release_count=$(echo "$filtered_releases" | jq length)
    
    for ((i=0; i<release_count; i++)); do
        local release
        release=$(echo "$filtered_releases" | jq -c ".[$i]")
        local tag_name
        local name
        local published_at
        local body
        local download_url
        local asset_name
        local is_prerelease
        
        tag_name=$(echo "$release" | jq -r '.tag_name')
        name=$(echo "$release" | jq -r '.name')
        published_at=$(echo "$release" | jq -r '.published_at')
        body=$(echo "$release" | jq -r '.body // "Release notes not available"')
        is_prerelease=$(echo "$release" | jq -r '.prerelease')
        
        # Get DMG asset
        local asset_info
        asset_info=$(echo "$release" | jq -r '.assets[] | select(.name | endswith(".dmg")) | {name: .name, download_url: .browser_download_url} | @base64' | head -1)
        
        if [[ -z "$asset_info" ]]; then
            print_warning "No DMG asset found for release $tag_name"
            continue
        fi
        
        download_url=$(echo "$asset_info" | base64 --decode | jq -r '.download_url')
        asset_name=$(echo "$asset_info" | base64 --decode | jq -r '.name')
        
        # Extract version (remove 'v' prefix)
        local version="${tag_name#v}"
        
        # Get build number
        local build_number
        build_number=$(extract_build_number "$version" "$asset_name")
        
        # Get file size
        local file_size
        file_size=$(get_file_size "$download_url")
        
        # Generate signature
        local signature
        signature=$(generate_signature "$download_url")
        
        # Convert published date to RFC 2822 format
        local pub_date
        if command -v gdate &> /dev/null; then
            pub_date=$(gdate -d "$published_at" -R)
        else
            pub_date=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${published_at%.*}Z" "+%a, %d %b %Y %H:%M:%S %z" 2>/dev/null || echo "$(date -R)")
        fi
        
        # Clean body for XML
        local clean_body
        clean_body=$(echo "$body" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        
        # Add pre-release indicator to title if needed
        local item_title="$name"
        if [[ "$is_prerelease" == "true" && "$item_title" != *"Pre-release"* ]]; then
            item_title="$item_title (Pre-release)"
        fi
        
        cat << EOF
        <item>
            <title>$item_title</title>
            <link>$download_url</link>
            <sparkle:version>$build_number</sparkle:version>
            <sparkle:shortVersionString>$version</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>$item_title</h2>
                <div>$clean_body</div>
            ]]></description>
            <pubDate>$pub_date</pubDate>
            <enclosure 
                url="$download_url"
                length="$file_size"
                type="application/octet-stream"
                sparkle:edSignature="$signature"
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
        
EOF
    done
    
    cat << EOF
    </channel>
</rss>
EOF
}

# Main function
main() {
    print_info "Starting appcast generation..."
    
    check_required_tools
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Fetch releases from GitHub
    print_info "Fetching releases from GitHub..."
    
    local releases_json
    if ! releases_json=$(gh release list --repo "$GITHUB_REPO_FULL" --limit 50 --json tagName,name,publishedAt,body,assets,prerelease 2>/dev/null); then
        print_error "Failed to fetch releases from GitHub"
        print_info "Make sure you're authenticated with 'gh auth login'"
        exit 1
    fi
    
    local release_count
    release_count=$(echo "$releases_json" | jq length)
    print_success "Fetched $release_count releases"
    
    # Generate stable appcast (stable releases only)
    print_info "Generating stable appcast (appcast.xml)..."
    generate_appcast_content "CodeLooper Updates" "$releases_json" "false" > appcast.xml
    print_success "Generated appcast.xml"
    
    # Generate pre-release appcast (all releases)
    print_info "Generating pre-release appcast (appcast-prerelease.xml)..."
    generate_appcast_content "CodeLooper Updates (Pre-release)" "$releases_json" "true" > appcast-prerelease.xml
    print_success "Generated appcast-prerelease.xml"
    
    # Validate XML files
    for appcast in appcast.xml appcast-prerelease.xml; do
        if xmllint --noout "$appcast" 2>/dev/null; then
            print_success "$appcast is valid XML"
        else
            print_warning "$appcast may have XML validation issues"
        fi
    done
    
    print_success "✅ Appcast generation completed!"
    
    # Show summary
    echo
    print_info "Generated files:"
    print_info "  📄 appcast.xml (stable releases only)"
    print_info "  📄 appcast-prerelease.xml (all releases)"
    
    if [[ -f "$SIGNATURES_CACHE" ]]; then
        local cached_count
        cached_count=$(wc -l < "$SIGNATURES_CACHE")
        print_info "  🔐 $cached_count signatures cached"
    fi
    
    echo
    print_info "Next steps:"
    print_info "1. Commit the updated appcast files"
    print_info "2. Push to GitHub to update the live feeds"
    print_info "3. Test the update channels in your app"
}

# Run main function
main "$@"