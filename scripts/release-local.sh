#!/bin/bash
# Local Release Script for CodeLooper
# This script handles the complete release process locally:
# 1. Build and notarize the app
# 2. Create DMG
# 3. Sign with Sparkle EdDSA
# 4. Update appcast.xml
# 5. Create GitHub release

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check for required tools
check_requirements() {
    log "Checking requirements..."
    
    # Check for GitHub CLI
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) is not installed. Install with: brew install gh"
        exit 1
    fi
    
    # Check for Sparkle tools
    if [ ! -f "/opt/homebrew/Caskroom/sparkle/2.7.0/bin/sign_update" ]; then
        error "Sparkle tools not found. Install with: brew install --cask sparkle"
        exit 1
    fi
    
    # Check GitHub auth
    if ! gh auth status &> /dev/null; then
        error "Not authenticated with GitHub. Run: gh auth login"
        exit 1
    fi
    
    log "✅ All requirements met"
}

# Get version from Info.plist
get_version() {
    local version=$(defaults read "${PROJECT_ROOT}/App/Info.plist" CFBundleShortVersionString)
    local build=$(defaults read "${PROJECT_ROOT}/App/Info.plist" CFBundleVersion)
    echo "${version}"
}

# Main release process
main() {
    check_requirements
    
    local VERSION=$(get_version)
    local TAG="v${VERSION}"
    
    log "🚀 Starting release process for CodeLooper ${VERSION}"
    
    # Step 1: Check if we're on a clean state
    if [ -n "$(git status --porcelain)" ]; then
        warn "Working directory has uncommitted changes"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Step 2: Regenerate Xcode project
    log "Regenerating Xcode project..."
    ./scripts/generate-xcproj.sh
    
    # Step 3: Build with xcodebuild
    log "Building Release configuration..."
    xcodebuild -workspace CodeLooper.xcworkspace \
               -scheme CodeLooper \
               -configuration Release \
               -derivedDataPath DerivedData \
               clean build \
               ONLY_ACTIVE_ARCH=NO \
               CODE_SIGN_IDENTITY="Developer ID Application"
    
    # Step 4: Copy app to binary directory
    log "Copying app bundle..."
    rm -rf binary/CodeLooper.app
    cp -R "$(find DerivedData -name "CodeLooper.app" -path "*/Release/*" | head -1)" binary/
    
    # Step 5: Notarize
    log "Notarizing app..."
    # Create zip for notarization
    cd binary
    ditto -c -k --keepParent CodeLooper.app CodeLooper-notarize.zip
    cd ..
    
    # Submit for notarization
    xcrun notarytool submit binary/CodeLooper-notarize.zip \
        --key "$(pwd)/binary/private_keys/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8" \
        --key-id "${APP_STORE_CONNECT_KEY_ID}" \
        --issuer "${APP_STORE_CONNECT_ISSUER_ID}" \
        --wait
    
    # Staple
    xcrun stapler staple binary/CodeLooper.app
    
    # Step 6: Create DMG
    log "Creating DMG..."
    ./scripts/create-dmg.sh \
        --app-path binary/CodeLooper.app \
        --output-dir artifacts \
        --app-version "${VERSION}"
    
    local DMG_PATH="artifacts/CodeLooper-macOS-${VERSION}.dmg"
    
    # Step 7: Sign DMG with code signature
    log "Code signing DMG..."
    codesign --force --sign "Developer ID Application" "${DMG_PATH}"
    
    # Step 8: Sign with Sparkle EdDSA
    log "Signing with Sparkle EdDSA..."
    local SPARKLE_SIG=$(/opt/homebrew/Caskroom/sparkle/2.7.0/bin/sign_update "${DMG_PATH}")
    log "Sparkle signature: ${SPARKLE_SIG}"
    
    # Extract just the signature
    local ED_SIGNATURE=$(echo "$SPARKLE_SIG" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
    local FILE_SIZE=$(stat -f%z "${DMG_PATH}")
    
    # Step 9: Update appcast.xml
    log "Updating appcast.xml..."
    local PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
    
    cat > appcast.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>CodeLooper</title>
        <link>https://raw.githubusercontent.com/steipete/CodeLooper/main/appcast.xml</link>
        <description>Most recent changes with links to updates.</description>
        <language>en</language>
        <item>
            <title>Version ${VERSION}</title>
            <sparkle:version>$(defaults read "${PROJECT_ROOT}/App/Info.plist" CFBundleVersion)</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <link>https://github.com/steipete/CodeLooper</link>
            <sparkle:releaseNotesLink>https://github.com/steipete/CodeLooper/releases/tag/${TAG}</sparkle:releaseNotesLink>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
            <enclosure 
                url="https://github.com/steipete/CodeLooper/releases/download/${TAG}/CodeLooper-macOS-${VERSION}.dmg" 
                type="application/octet-stream"
                sparkle:edSignature="${ED_SIGNATURE}"
                length="${FILE_SIZE}"
            />
        </item>
    </channel>
</rss>
EOF
    
    # Step 10: Commit appcast.xml
    log "Committing appcast.xml..."
    git add appcast.xml
    git commit -m "Update appcast.xml for ${VERSION}" || true
    
    # Step 11: Create and push tag
    log "Creating git tag ${TAG}..."
    git tag -a "${TAG}" -m "Release ${VERSION}"
    
    # Step 12: Push changes
    log "Pushing to GitHub..."
    git push origin main
    git push origin "${TAG}"
    
    # Step 13: Create GitHub release
    log "Creating GitHub release..."
    local RELEASE_NOTES="## What's New in ${VERSION}

- Initial release with Sparkle auto-update support
- Signed and notarized for macOS 15+

## Installation

Download the DMG, open it, and drag CodeLooper to your Applications folder.

---
*This release was created locally and signed with EdDSA for automatic updates.*"
    
    gh release create "${TAG}" \
        --title "CodeLooper ${VERSION}" \
        --notes "${RELEASE_NOTES}" \
        "${DMG_PATH}"
    
    log "✅ Release ${VERSION} completed successfully!"
    log "📦 DMG uploaded to: https://github.com/steipete/CodeLooper/releases/tag/${TAG}"
    log "📋 Appcast URL: https://raw.githubusercontent.com/steipete/CodeLooper/main/appcast.xml"
    
    # Cleanup
    rm -f binary/CodeLooper-notarize.zip
}

# Run main function
main "$@"