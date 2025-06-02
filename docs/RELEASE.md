# Release Process for CodeLooper

This document describes the process for creating and publishing a new release of CodeLooper.

## Prerequisites

### Required Tools
- **Xcode 16.4+** - For building the app
- **GitHub CLI** (`gh`) - Install with `brew install gh`
- **Sparkle Tools** - Install with `brew install --cask sparkle`
- **Apple Developer Certificate** - "Developer ID Application" certificate in Keychain
- **App Store Connect API Key** - For notarization

### Environment Variables
Ensure these are set for notarization:
```bash
export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_P8_CONTENT="-----BEGIN PRIVATE KEY-----..."
```

### Sparkle Keys
- **Private Key**: Stored in macOS Keychain (account: "ed25519")
- **Public Key**: `oIgha2beQWnyCXgOIlB8+oaUzFNtWgkqq6jKXNNDhv4=` (in Info.plist)

## Release Types

### 1. Quick Release (Using Existing Build)
If you already have a built, signed, and notarized DMG:

```bash
./scripts/release-from-existing.sh
```

This script will:
- Sign the DMG with Sparkle EdDSA signature
- Update `appcast.xml` with release info
- Commit and push changes
- Create GitHub release with DMG

### 2. Full Release (Build from Source)
To build everything from scratch:

```bash
./scripts/release-local.sh
```

This script will:
- Regenerate Xcode project
- Build Release configuration
- Code sign with Developer ID
- Notarize with Apple
- Create DMG
- Sign with Sparkle
- Update appcast and create release

## Manual Release Process

If you prefer to do it step by step:

### Step 1: Update Version Numbers
Edit `App/Info.plist` and `CodeLooper/Info.plist`:
- `CFBundleShortVersionString` - Marketing version (e.g., "2025.5.30")
- `CFBundleVersion` - Build number (increment for each build)

### Step 2: Build the App
```bash
# Regenerate project
./scripts/generate-xcproj.sh

# Build with xcodebuild
xcodebuild -workspace CodeLooper.xcworkspace \
           -scheme CodeLooper \
           -configuration Release \
           -derivedDataPath DerivedData \
           clean build \
           ONLY_ACTIVE_ARCH=NO \
           CODE_SIGN_IDENTITY="Developer ID Application"

# Copy to binary directory
cp -R "$(find DerivedData -name "CodeLooper.app" -path "*/Release/*" | head -1)" binary/
```

### Step 3: Notarize
```bash
# Create zip for notarization
cd binary
ditto -c -k --keepParent CodeLooper.app CodeLooper-notarize.zip
cd ..

# Submit for notarization
xcrun notarytool submit binary/CodeLooper-notarize.zip \
    --key "private_keys/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8" \
    --key-id "${APP_STORE_CONNECT_KEY_ID}" \
    --issuer "${APP_STORE_CONNECT_ISSUER_ID}" \
    --wait

# Staple the ticket
xcrun stapler staple binary/CodeLooper.app
```

### Step 4: Create DMG
```bash
./scripts/create-dmg.sh \
    --app-path binary/CodeLooper.app \
    --output-dir artifacts \
    --app-version "2025.5.30"

# Code sign the DMG
codesign --force --sign "Developer ID Application" artifacts/CodeLooper-macOS-2025.5.30.dmg
```

### Step 5: Sign with Sparkle
```bash
# Get EdDSA signature
SPARKLE_SIG=$(/opt/homebrew/Caskroom/sparkle/2.7.0/bin/sign_update artifacts/CodeLooper-macOS-2025.5.30.dmg)
echo "$SPARKLE_SIG"
# Output: sparkle:edSignature="..." length="..."
```

### Step 6: Update appcast.xml
Update the appcast.xml file with:
- New version info
- Download URL
- EdDSA signature from previous step
- File size

### Step 7: Create GitHub Release
```bash
# Commit appcast
git add appcast.xml
git commit -m "Update appcast.xml for 2025.5.30"

# Create and push tag
git tag -a "v2025.5.30" -m "Release 2025.5.30"
git push origin main
git push origin "v2025.5.30"

# Create release
gh release create "v2025.5.30" \
    --title "CodeLooper 2025.5.30" \
    --notes "Release notes here" \
    artifacts/CodeLooper-macOS-2025.5.30.dmg
```

## Troubleshooting

### "Developer cannot be verified" for Sparkle tools
Remove quarantine attributes:
```bash
xattr -cr /opt/homebrew/Caskroom/sparkle/2.7.0/bin/
```

### Notarization fails
- Check API credentials are correct
- Ensure P8 key file has proper format (no literal \n)
- Verify Developer ID certificate is valid

### Sparkle signature issues
- Ensure private key is in Keychain (account: "ed25519")
- Use `/opt/homebrew/Caskroom/sparkle/2.7.0/bin/sign_update` directly
- The key format should be base64 without PEM headers

### GitHub release fails
- Ensure `gh auth status` shows you're logged in
- Check the tag doesn't already exist
- Verify DMG file path is correct

## Version Numbering

We use semantic versioning with year-based scheme:
- Format: `YYYY.M.PATCH` (e.g., "2025.5.30")
- Increment PATCH for bug fixes
- Increment M for new features
- Year changes annually

Build numbers should always increment, even for the same version.

## Testing Updates

To test the Sparkle update mechanism:

1. Build a version with a lower version number
2. Install and run it
3. Push the new release with higher version
4. Check if the app detects and installs the update

## Security Notes

- **Never commit private keys** to the repository
- The Sparkle private key is in macOS Keychain
- Keep your Developer ID certificate secure
- Rotate API keys periodically
- Always notarize releases for Gatekeeper

## Changelog and Release Notes System

### Overview
CodeLooper uses a dual changelog system for maximum compatibility:

1. **CHANGELOG.md** - Markdown format for developers and GitHub
2. **CHANGELOG.html** - Styled HTML for Sparkle release notes
3. **Inline HTML in appcast.xml** - Fallback for immediate display

### Updating Release Notes

#### 1. Update CHANGELOG.md
Add new version entry in Markdown format:

```markdown
## [1.1.0] - 2025-06-03

### 🎉 New Release

### Added
- **New Feature**: Description of what was added
- **Enhancement**: Improvement to existing functionality

### Fixed
- Bug fix descriptions

### Security
- Security improvements
```

#### 2. Update CHANGELOG.html
Copy content from CHANGELOG.md and convert to styled HTML:

```html
<div class="version">
    <h2>[1.1.0] - 2025-06-03</h2>
    <div class="release-type">🎉 New Release</div>
</div>

<div class="category">
    <h3>✨ Added</h3>
    <ul>
        <li><strong>New Feature</strong>: Description</li>
    </ul>
</div>
```

#### 3. Update appcast.xml
Update the inline HTML description:

```xml
<description><![CDATA[
    <h2>🎉 CodeLooper 1.1.0 - New Release</h2>
    
    <h3>✨ Added</h3>
    <ul>
        <li><strong>New Feature</strong>: Description</li>
    </ul>
    
    <p><a href="https://github.com/steipete/CodeLooper">View on GitHub</a></p>
]]></description>
```

### GitHub Pages Setup
Release notes are served via GitHub Pages for proper HTML rendering:

- **Location**: `docs/CHANGELOG.html`
- **URL**: `https://steipete.github.io/CodeLooper/CHANGELOG.html`
- **Fallback**: Inline HTML in appcast.xml for immediate display

The system automatically uses GitHub Pages when available, with appcast.xml inline content as fallback.

### Automatic Update Checks
The app now checks for updates automatically:

- **On Startup**: Checks for updates 2 seconds after launch (background)
- **Automatic**: Sparkle checks periodically based on user preferences
- **Manual**: Users can trigger via Settings > About > Check for Updates

Configuration in `SparkleUpdaterManager.swift`:
```swift
// Enable automatic update checks
controller.updater.automaticallyChecksForUpdates = true

// Check for updates on startup
Task { @MainActor in
    try? await Task.sleep(for: .seconds(2))
    controller.updater.checkForUpdatesInBackground()
}
```

## EdDSA Key Management

### Key Storage and Backup
- **Primary**: macOS Keychain (service: "https://sparkle-project.org", account: "ed25519")
- **Backup Location**: `/Users/steipete/Library/CloudStorage/Dropbox/certificates/May2025/CodeLooper/`
- **Public Key**: `oIgha2beQWnyCXgOIlB8+oaUzFNtWgkqq6jKXNNDhv4=`
- **Private Key**: `Q+Mf0guV/149574+2YMM5njgGxDVoy5nNMnjN6Wl05I=`

### Restoring Keys
If keys are lost from Keychain, restore from backup:

```bash
# Restore private key to keychain
security add-generic-password \
    -s "https://sparkle-project.org" \
    -a "ed25519" \
    -w "Q+Mf0guV/149574+2YMM5njgGxDVoy5nNMnjN6Wl05I=" \
    -D "private key" \
    -j "Public key (SUPublicEDKey value) for this key is: oIgha2beQWnyCXgOIlB8+oaUzFNtWgkqq6jKXNNDhv4=" \
    -T "" -U
```

### Signing Process
The signing process has been streamlined:

```bash
# Using built-in Sparkle tools
./.build/artifacts/sparkle/Sparkle/bin/sign_update binary/CodeLooper-macOS-v1.0.0.dmg

# Output format:
# sparkle:edSignature="..." length="..."
```

### DMG Volume Naming
DMG volumes are now named simply "CodeLooper" (not "CodeLooper Installer") for cleaner user experience:

```bash
./scripts/create-dmg.sh \
    --volume-name "CodeLooper" \
    --app-path binary/CodeLooper.app \
    --output-dir binary
```

## Complete Release Checklist

### Pre-Release
- [ ] Update version numbers in Info.plist files
- [ ] Update CHANGELOG.md with new version
- [ ] Update CHANGELOG.html with styled content
- [ ] Update appcast.xml with inline HTML description
- [ ] Test build and functionality

### Build and Sign
- [ ] Generate Xcode project: `./scripts/generate-xcproj.sh`
- [ ] Build with full notarization: `./scripts/build-and-notarize.sh --create-dmg --app-version vX.X.X`
- [ ] Verify DMG volume name is "CodeLooper"
- [ ] Sign DMG with EdDSA: `./.build/artifacts/sparkle/Sparkle/bin/sign_update`

### Release
- [ ] Update appcast.xml with signature and file size
- [ ] Commit and push changelog updates
- [ ] Create GitHub release with signed DMG
- [ ] Test Sparkle update from previous version
- [ ] Verify release notes display correctly in Sparkle dialog

### Post-Release
- [ ] Test automatic update check on startup
- [ ] Verify GitHub Pages serves CHANGELOG.html correctly
- [ ] Monitor for any update issues or user reports
- [ ] Update documentation if needed

## Backup

Important files to backup:
- **Sparkle EdDSA Keys**: In Keychain + `/Users/steipete/Library/CloudStorage/Dropbox/certificates/May2025/CodeLooper/`
- **Developer ID Certificate**: (.p12) in Dropbox
- **App Store Connect API Key**: (.p8) in Dropbox
- **Release Scripts**: All scripts in `/scripts/` directory
- **Appcast**: `appcast.xml` (version controlled)
- **Changelog Files**: `CHANGELOG.md` and `docs/CHANGELOG.html`

### Backup Verification
Regularly verify backup integrity:
```bash
# Check Keychain key
security find-generic-password -s "https://sparkle-project.org" -a "ed25519" -g

# Check Dropbox backup files
ls -la "/Users/steipete/Library/CloudStorage/Dropbox/certificates/May2025/CodeLooper/"

# Verify public key matches app
grep -A1 "SUPublicEDKey" App/Info.plist
```