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

## Backup

Important files to backup:
- Sparkle private key (in Keychain)
- Developer ID certificate (.p12)
- App Store Connect API key (.p8)
- Current location: `/Users/steipete/Library/CloudStorage/Dropbox/certificates/May2025/`