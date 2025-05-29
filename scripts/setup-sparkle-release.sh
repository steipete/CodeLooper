#!/bin/bash

# CodeLooper - GitHub Releases + Sparkle Setup Script
# This script sets up the complete workflow for GitHub releases with Sparkle auto-updates

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Setting up CodeLooper for GitHub Releases + Sparkle Auto-Updates"
echo "Project root: $PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "\n${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step "Step 1: Generate Sparkle EdDSA Keys"

# Create keys directory
mkdir -p "$PROJECT_ROOT/private"
cd "$PROJECT_ROOT/private"

# Check if keys already exist
if [[ -f "sparkle_private_key" && -f "sparkle_public_key" ]]; then
    print_warning "Sparkle keys already exist in private/ directory"
    echo "Public key content:"
    cat sparkle_public_key
else
    # Generate EdDSA keys using OpenSSL (alternative to Sparkle's generate_keys)
    print_step "Generating EdDSA key pair..."
    
    # Generate private key
    openssl genpkey -algorithm Ed25519 -out sparkle_private_key
    
    # Extract public key
    openssl pkey -in sparkle_private_key -pubout -outform DER | base64 > sparkle_public_key
    
    print_success "Generated Sparkle EdDSA keys"
    echo "Public key (add this to Info.plist):"
    cat sparkle_public_key
fi

print_step "Step 2: Update Info.plist with Sparkle Configuration"

# Read the current public key
PUBLIC_KEY=$(cat sparkle_public_key)

# Update Info.plist files with proper Sparkle configuration
# Note: You'll need to replace YOUR_GITHUB_USERNAME with actual username
GITHUB_USERNAME="${GITHUB_USERNAME:-YOUR_GITHUB_USERNAME}"
APPCAST_URL="https://raw.githubusercontent.com/$GITHUB_USERNAME/CodeLooper/main/appcast.xml"

print_step "Step 3: Creating GitHub Release Scripts"

# Create release script
cat > "$PROJECT_ROOT/scripts/create-github-release.sh" << 'EOF'
#!/bin/bash

# GitHub Release Creation Script for CodeLooper
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Get version from Project.swift
VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"MARKETING_VERSION": "\(.*\)".*/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"CURRENT_PROJECT_VERSION": "\(.*\)".*/\1/')

echo "📦 Creating GitHub release for CodeLooper v$VERSION (build $BUILD_NUMBER)"

# Build the app
echo "🔨 Building application..."
cd "$PROJECT_ROOT"
./scripts/build-and-notarize.sh

# Check if built app exists
APP_PATH="$PROJECT_ROOT/build/Build/Products/Release/CodeLooper.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ Built app not found at $APP_PATH"
    exit 1
fi

# Create DMG
echo "📀 Creating DMG..."
DMG_PATH="$PROJECT_ROOT/build/CodeLooper-$VERSION.dmg"
./scripts/create-dmg.sh "$APP_PATH" "$DMG_PATH"

# Generate release notes
RELEASE_NOTES="Release notes for CodeLooper v$VERSION

This release includes:
- Latest features and improvements
- Bug fixes and performance enhancements

## Installation
1. Download the DMG file
2. Open it and drag CodeLooper to Applications
3. Grant necessary permissions when prompted

## Auto-Updates
This version supports automatic updates via Sparkle."

# Create GitHub release (requires gh CLI)
echo "🚀 Creating GitHub release..."
gh release create "v$VERSION" "$DMG_PATH" \
    --title "CodeLooper v$VERSION" \
    --notes "$RELEASE_NOTES" \
    --generate-notes

# Update appcast.xml
echo "📡 Updating appcast.xml..."
./scripts/update-appcast.sh "$VERSION" "$BUILD_NUMBER" "$DMG_PATH"

echo "✅ GitHub release created successfully!"
echo "📡 Don't forget to commit and push the updated appcast.xml"
EOF

chmod +x "$PROJECT_ROOT/scripts/create-github-release.sh"

# Create appcast update script
cat > "$PROJECT_ROOT/scripts/update-appcast.sh" << 'EOF'
#!/bin/bash

# Appcast.xml Update Script
set -euo pipefail

VERSION="$1"
BUILD_NUMBER="$2"
DMG_PATH="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📡 Updating appcast.xml for version $VERSION"

# Calculate file size and SHA256
DMG_SIZE=$(stat -f%z "$DMG_PATH")
DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)
DMG_FILENAME=$(basename "$DMG_PATH")

# Get current date in RFC 2822 format
RELEASE_DATE=$(date -R)

# GitHub release URL
GITHUB_USERNAME="${GITHUB_USERNAME:-YOUR_GITHUB_USERNAME}"
DOWNLOAD_URL="https://github.com/$GITHUB_USERNAME/CodeLooper/releases/download/v$VERSION/$DMG_FILENAME"

# Create or update appcast.xml
cat > "$PROJECT_ROOT/appcast.xml" << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>CodeLooper Updates</title>
        <link>https://github.com/$GITHUB_USERNAME/CodeLooper</link>
        <description>CodeLooper automatic updates feed</description>
        <language>en</language>
        
        <item>
            <title>CodeLooper $VERSION</title>
            <link>$DOWNLOAD_URL</link>
            <sparkle:version>$BUILD_NUMBER</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>CodeLooper $VERSION</h2>
                <p>Latest version of CodeLooper with new features and improvements.</p>
                <ul>
                    <li>Enhanced monitoring capabilities</li>
                    <li>Improved intervention strategies</li>
                    <li>Bug fixes and performance improvements</li>
                </ul>
            ]]></description>
            <pubDate>$RELEASE_DATE</pubDate>
            <enclosure 
                url="$DOWNLOAD_URL"
                length="$DMG_SIZE"
                type="application/octet-stream"
                sparkle:edSignature="SIGNATURE_PLACEHOLDER"
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
APPCAST_EOF

echo "✅ Appcast.xml updated"
echo "⚠️  Remember to sign the DMG with your Sparkle private key and update the signature"
echo "⚠️  Command: sign_update '$DMG_PATH' /path/to/sparkle_private_key"
EOF

chmod +x "$PROJECT_ROOT/scripts/update-appcast.sh"

print_step "Step 4: Setup Instructions"

cat << SETUP_EOF

🎉 Sparkle + GitHub Releases setup is almost complete!

📋 NEXT STEPS:

1. 🔑 Update Info.plist with your public key:
   Replace 'YOUR_SPARKLE_PUBLIC_ED_KEY_HERE' with:
   $(cat sparkle_public_key)

2. 🌐 Set your GitHub username:
   export GITHUB_USERNAME="your-github-username"
   
3. 📝 Update appcast URL in Info.plist:
   Replace 'YOUR_APPCAST_URL_HERE' with:
   https://raw.githubusercontent.com/your-github-username/CodeLooper/main/appcast.xml

4. 🔧 Install required tools:
   - GitHub CLI: brew install gh
   - Sign into GitHub: gh auth login

5. 🚀 Create your first release:
   ./scripts/create-github-release.sh

6. 📡 Host appcast.xml:
   - Commit appcast.xml to your repository
   - Ensure it's accessible at the URL in your Info.plist

🔒 SECURITY NOTES:
- Keep 'private/sparkle_private_key' SECRET and secure
- Add 'private/' to .gitignore
- Consider using GitHub secrets for CI/CD

📁 FILES CREATED:
- private/sparkle_private_key (KEEP SECRET!)
- private/sparkle_public_key
- scripts/create-github-release.sh
- scripts/update-appcast.sh

SETUP_EOF

# Add private directory to .gitignore if not already there
if ! grep -q "private/" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
    echo -e "\n# Sparkle private keys\nprivate/" >> "$PROJECT_ROOT/.gitignore"
    print_success "Added private/ to .gitignore"
fi

print_success "Sparkle + GitHub Releases setup completed!"
print_warning "Don't forget to complete the manual steps above!"