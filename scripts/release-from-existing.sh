#!/bin/bash
# Release from existing notarized DMG
# This script creates a GitHub release from an already built and notarized DMG

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check requirements
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) not installed. Install with: brew install gh"
fi

if ! gh auth status &> /dev/null; then
    error "Not authenticated with GitHub. Run: gh auth login"
fi

# Get version
VERSION=$(defaults read "${PROJECT_ROOT}/App/Info.plist" CFBundleShortVersionString)
BUILD=$(defaults read "${PROJECT_ROOT}/App/Info.plist" CFBundleVersion)
TAG="v${VERSION}"

log "🚀 Creating release for CodeLooper ${VERSION} (Build ${BUILD})"

# Check if DMG exists
DMG_PATH="artifacts/CodeLooper-macOS-${VERSION}-notarized.dmg"
if [ ! -f "${DMG_PATH}" ]; then
    # Try without -notarized suffix
    DMG_PATH="artifacts/CodeLooper-macOS-${VERSION}.dmg"
    if [ ! -f "${DMG_PATH}" ]; then
        error "DMG not found. Expected: ${DMG_PATH}"
    fi
fi

log "Found DMG: ${DMG_PATH}"

# Sign with Sparkle if not already done
log "Getting Sparkle signature..."
SPARKLE_OUTPUT=$(/opt/homebrew/Caskroom/sparkle/2.7.0/bin/sign_update "${DMG_PATH}")
ED_SIGNATURE=$(echo "$SPARKLE_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
FILE_SIZE=$(stat -f%z "${DMG_PATH}")

log "EdDSA Signature: ${ED_SIGNATURE}"

# Update appcast.xml
log "Updating appcast.xml..."
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

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
            <sparkle:version>${BUILD}</sparkle:version>
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

# Create release notes from CHANGELOG if exists
if [ -f "CHANGELOG.md" ]; then
    # Extract latest version notes
    RELEASE_NOTES=$(awk "/^## ${VERSION}|^## \[${VERSION}\]/{flag=1; next} /^## /{flag=0} flag" CHANGELOG.md)
else
    RELEASE_NOTES="## CodeLooper ${VERSION}

### What's New
- Initial release with automatic update support via Sparkle
- Monitors Cursor IDE instances and handles stuck states
- AI-powered diagnostics and recovery
- Signed and notarized for macOS 15+

### Installation
1. Download the DMG
2. Open it and drag CodeLooper to Applications
3. Launch CodeLooper from Applications
4. Grant necessary permissions when prompted"
fi

# Commit appcast
log "Committing appcast.xml..."
git add appcast.xml
git commit -m "Update appcast.xml for ${VERSION}" || warn "No changes to commit"

# Create and push tag
log "Creating git tag ${TAG}..."
if git rev-parse "${TAG}" >/dev/null 2>&1; then
    warn "Tag ${TAG} already exists. Delete it first with: git tag -d ${TAG} && git push origin :${TAG}"
    read -p "Delete and recreate tag? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git tag -d "${TAG}"
        git push origin ":${TAG}" || true
    else
        error "Tag already exists"
    fi
fi

git tag -a "${TAG}" -m "Release ${VERSION}"

# Push
log "Pushing to GitHub..."
git push origin main
git push origin "${TAG}"

# Rename DMG for release if needed
RELEASE_DMG="CodeLooper-macOS-${VERSION}.dmg"
if [[ "${DMG_PATH}" == *"-notarized.dmg" ]]; then
    cp "${DMG_PATH}" "artifacts/${RELEASE_DMG}"
    DMG_PATH="artifacts/${RELEASE_DMG}"
fi

# Create GitHub release
log "Creating GitHub release..."
gh release create "${TAG}" \
    --title "CodeLooper ${VERSION}" \
    --notes "${RELEASE_NOTES}" \
    "${DMG_PATH}#CodeLooper-macOS-${VERSION}.dmg"

log "✅ Release ${VERSION} completed!"
log "📦 Release URL: https://github.com/steipete/CodeLooper/releases/tag/${TAG}"
log "📋 Appcast URL: https://raw.githubusercontent.com/steipete/CodeLooper/main/appcast.xml"
log ""
log "🎉 Users with auto-update enabled will receive this update automatically!"