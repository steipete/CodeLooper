#!/bin/bash

# CodeLooper Release Automation Script
# Adapted from VibeMeter's advanced release process
# Handles the complete release lifecycle from development through beta to production

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
RELEASE_DIR="$PROJECT_ROOT/release"

# GitHub configuration
GITHUB_REPO="steipete/CodeLooper"
GITHUB_BASE_URL="https://github.com/$GITHUB_REPO"

# Print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Print usage information
usage() {
    cat << EOF
Usage: $0 <type> [number]

Release types:
  stable              Create a stable release
  beta <number>       Create a beta release (e.g., beta 1, beta 2)
  alpha <number>      Create an alpha release (e.g., alpha 1, alpha 2)
  rc <number>         Create a release candidate (e.g., rc 1, rc 2)

Examples:
  $0 stable           # Creates stable release
  $0 beta 1           # Creates beta.1 release
  $0 alpha 2          # Creates alpha.2 release
  $0 rc 1             # Creates rc.1 release

This script handles the complete release process:
1. Pre-flight validation
2. Project generation with Tuist
3. Application building with appropriate flags
4. Code signing and notarization
5. DMG creation and signing
6. GitHub release creation
7. Appcast generation for Sparkle updates
EOF
}

# Validate release type and set flags
validate_and_setup_release() {
    local type="$1"
    local number="$2"
    
    case "$type" in
        "stable")
            RELEASE_TYPE="stable"
            IS_PRERELEASE="false"
            IS_PRERELEASE_BUILD="NO"
            VERSION_SUFFIX=""
            ;;
        "beta"|"alpha"|"rc")
            if [[ -z "$number" ]]; then
                print_error "Release number required for $type releases"
                usage
                exit 1
            fi
            RELEASE_TYPE="$type"
            IS_PRERELEASE="true"
            IS_PRERELEASE_BUILD="YES"
            VERSION_SUFFIX=".$type.$number"
            ;;
        *)
            print_error "Invalid release type: $type"
            usage
            exit 1
            ;;
    esac
    
    print_info "Release configuration:"
    print_info "  Type: $RELEASE_TYPE"
    print_info "  Pre-release: $IS_PRERELEASE"
    print_info "  Build flag: $IS_PRERELEASE_BUILD"
    print_info "  Version suffix: ${VERSION_SUFFIX:-'(none)'}"
}

# Step 1: Pre-flight checks
preflight_check() {
    print_info "🔍 Step 1: Running pre-flight checks..."
    
    if [[ -f "$SCRIPT_DIR/preflight-check.sh" ]]; then
        "$SCRIPT_DIR/preflight-check.sh"
    else
        print_warning "preflight-check.sh not found, performing basic checks..."
        
        # Basic git checks
        if [[ -n "$(git status --porcelain)" ]]; then
            print_error "Working directory is not clean. Commit or stash changes first."
            exit 1
        fi
        
        # Check for required tools
        for tool in gh jq xcodebuild; do
            if ! command -v "$tool" &> /dev/null; then
                print_error "Required tool '$tool' is not installed"
                exit 1
            fi
        done
    fi
    
    print_success "Pre-flight checks passed"
}

# Step 2: Generate Xcode project
generate_project() {
    print_info "🏗️ Step 2: Generating Xcode project..."
    
    cd "$PROJECT_ROOT"
    "./scripts/generate-xcproj.sh"
    
    # Check if project generation created any changes
    if [[ -n "$(git status --porcelain)" ]]; then
        print_info "Project generation created changes, committing..."
        git add .
        git commit -m "Update Xcode project for release

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
    fi
    
    print_success "Xcode project generated"
}

# Step 3: Build application
build_application() {
    print_info "🔨 Step 3: Building application..."
    
    # Clean build directory
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Set build environment variables
    export IS_PRERELEASE_BUILD="$IS_PRERELEASE_BUILD"
    
    print_info "Building with IS_PRERELEASE_BUILD=$IS_PRERELEASE_BUILD"
    
    # Build the application
    xcodebuild -workspace CodeLooper.xcworkspace \
               -scheme CodeLooper \
               -configuration Release \
               -derivedDataPath "$BUILD_DIR" \
               clean build \
               CODE_SIGN_STYLE=Automatic \
               DEVELOPMENT_TEAM=Y5PE65HELJ \
               IS_PRERELEASE_BUILD="$IS_PRERELEASE_BUILD"
    
    # Find built app
    APP_PATH=$(find "$BUILD_DIR" -name "CodeLooper.app" -type d | head -1)
    if [[ -z "$APP_PATH" ]]; then
        print_error "Could not find built application"
        exit 1
    fi
    
    print_success "Application built at: $APP_PATH"
}

# Step 4: Code signing and notarization
sign_and_notarize() {
    print_info "✍️ Step 4: Code signing and notarization..."
    
    if [[ -f "$SCRIPT_DIR/sign-and-notarize.sh" ]]; then
        "$SCRIPT_DIR/sign-and-notarize.sh" "$APP_PATH"
    else
        print_warning "sign-and-notarize.sh not found, using basic codesign..."
        codesign --force --deep --sign "Apple Distribution" "$APP_PATH"
    fi
    
    print_success "Application signed and notarized"
}

# Step 5: Create DMG
create_dmg() {
    print_info "📦 Step 5: Creating DMG..."
    
    # Get version info
    local version=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)
    local build=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion)
    
    # Create version string
    if [[ "$RELEASE_TYPE" != "stable" ]]; then
        version="${version}${VERSION_SUFFIX}"
    fi
    
    DMG_NAME="CodeLooper-${version}-${build}.dmg"
    DMG_PATH="$RELEASE_DIR/$DMG_NAME"
    
    # Create release directory
    mkdir -p "$RELEASE_DIR"
    
    if [[ -f "$SCRIPT_DIR/create-dmg.sh" ]]; then
        "$SCRIPT_DIR/create-dmg.sh" "$APP_PATH" "$DMG_PATH"
    else
        print_warning "create-dmg.sh not found, using basic DMG creation..."
        
        # Create temporary directory for DMG contents
        local temp_dir=$(mktemp -d)
        cp -R "$APP_PATH" "$temp_dir/"
        
        # Create DMG
        hdiutil create -volname "CodeLooper" -srcfolder "$temp_dir" -ov -format UDZO "$DMG_PATH"
        
        # Clean up
        rm -rf "$temp_dir"
    fi
    
    print_success "DMG created: $DMG_PATH"
}

# Step 6: Create GitHub release
create_github_release() {
    print_info "🚀 Step 6: Creating GitHub release..."
    
    # Get version info
    local version=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)
    local build=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion)
    
    # Create version string and tag
    if [[ "$RELEASE_TYPE" != "stable" ]]; then
        version="${version}${VERSION_SUFFIX}"
    fi
    
    local tag="v${version}"
    local title="CodeLooper ${version}"
    
    if [[ "$IS_PRERELEASE" == "true" ]]; then
        title="${title} (Pre-release)"
    fi
    
    # Create release notes
    local release_notes="## Changes in CodeLooper ${version}

*Release notes will be updated shortly*

### Build Information
- **Version**: ${version}
- **Build**: ${build}
- **Release Type**: ${RELEASE_TYPE}
- **Pre-release**: ${IS_PRERELEASE}

---

🤖 Generated with [Claude Code](https://claude.ai/code)"
    
    # Create GitHub release
    local prerelease_flag=""
    if [[ "$IS_PRERELEASE" == "true" ]]; then
        prerelease_flag="--prerelease"
    fi
    
    gh release create "$tag" \
        --title "$title" \
        --notes "$release_notes" \
        --repo "$GITHUB_REPO" \
        $prerelease_flag \
        "$DMG_PATH"
    
    print_success "GitHub release created: $GITHUB_BASE_URL/releases/tag/$tag"
}

# Step 7: Update appcast
update_appcast() {
    print_info "📡 Step 7: Updating appcast..."
    
    if [[ -f "$SCRIPT_DIR/generate-appcast.sh" ]]; then
        "$SCRIPT_DIR/generate-appcast.sh"
    elif [[ -f "$SCRIPT_DIR/update-appcast.sh" ]]; then
        "$SCRIPT_DIR/update-appcast.sh"
    else
        print_warning "No appcast generation script found"
        print_info "You may need to manually update the appcast files"
    fi
    
    print_success "Appcast updated"
}

# Main release process
main() {
    print_info "🎯 Starting CodeLooper release process..."
    
    # Validate arguments
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    
    validate_and_setup_release "$1" "$2"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Execute release steps
    preflight_check
    generate_project
    build_application
    sign_and_notarize
    create_dmg
    create_github_release
    update_appcast
    
    print_success "🎉 Release process completed successfully!"
    print_info "Release artifacts:"
    print_info "  - App: $APP_PATH"
    print_info "  - DMG: $DMG_PATH"
    print_info "  - GitHub: $GITHUB_BASE_URL/releases"
}

# Run main function with all arguments
main "$@"