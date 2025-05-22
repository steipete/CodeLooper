# CodeLooper Mac App Distribution Guide

This document explains how to build, code sign, notarize, and distribute the CodeLooper Mac application.

## Prerequisites

1. **Xcode**: Latest version recommended (14.0+)
2. **Apple Developer Account**: Required for code signing and notarization
3. **Developer ID Application Certificate**: Required for distribution outside the Mac App Store
4. **App-specific password**: Required for notarization

## Quick Start

For a complete end-to-end build, sign, and notarize workflow, use:

```bash
./build-and-notarize.sh
```

This script handles the entire process with appropriate defaults.

## Step-by-Step Distribution Process

If you need more control, you can run each step individually.

### 1. Build the Application

```bash
./scripts/run-app.sh
```

### 2. Code Sign the Application

```bash
./scripts/sign-and-notarize.sh --sign-only --identity "Developer ID Application: Your Name (TEAMID)"
```

### 3. Notarize the Application

```bash
./scripts/sign-and-notarize.sh --notarize-only
```

The notarization script supports both standard development environments and CI environments with a unified interface. Additional options include:

```bash
# Using API Key authentication instead of Apple ID
./scripts/notarize-mac.sh --api-key-path /path/to/key.p8 --api-key-id KEY_ID --api-key-issuer ISSUER_ID

# Skip stapling (useful for testing)
./scripts/notarize-mac.sh --skip-staple

# Force re-signing before notarization
./scripts/notarize-mac.sh --force-resign

# Enable GitHub Actions integration for better CI reporting
./scripts/notarize-mac.sh --github-actions

# Set custom timeout (in minutes)
./scripts/notarize-mac.sh --timeout 45
```

## Setting up Notarization Credentials

Notarization requires Apple Developer credentials. You can provide these in three ways:

### 1. Environment Variables

```bash
export APPLE_ID="your.email@example.com"
export APPLE_PASSWORD="your-app-specific-password"
export APPLE_TEAM_ID="YOURTEAMID"
export APPLE_IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

### 2. Command Line Arguments

```bash
./scripts/notarize-mac.sh --apple-id "your.email@example.com" --apple-password "your-app-specific-password" --apple-team-id "YOURTEAMID" --apple-identity "Developer ID Application: Your Name (TEAMID)"
```

### 3. Environment File (Recommended)

Create a file named `.env.notarize` in the mac directory with the following contents:

```
APPLE_ID=your.email@example.com
APPLE_PASSWORD=your-app-specific-password
APPLE_TEAM_ID=YOURTEAMID
APPLE_IDENTITY=Developer ID Application: Your Name (TEAMID)
```

## Obtaining Required Credentials

### Finding Your Team ID

1. Go to [Apple Developer Account](https://developer.apple.com/account)
2. Click on "Membership" in the sidebar
3. Your Team ID appears under "Team ID"

### Creating an App-Specific Password

1. Go to [Apple ID Account Page](https://appleid.apple.com)
2. Sign in with your Apple ID
3. In the "Security" section, click "Generate Password" under "App-Specific Passwords"
4. Follow the instructions to create and save your password

### Finding Your Developer ID Certificate

List available signing identities with:

```bash
security find-identity -v -p codesigning
```

Look for a certificate that starts with "Developer ID Application:" and use the entire string including the ID in parentheses.

## CI/CD Integration

For continuous integration environments, use `ci-notarize-mac.sh` which provides:

- Better error handling and reporting
- Support for environment variables and secure storage
- Automatic retry mechanism for network issues
- Detailed progress reporting

## Troubleshooting

### Common Issues

1. **"No signing certificate found"**: Ensure you have a valid Developer ID certificate installed
2. **"Notarization failed"**: Check the notarization log at `binary/notarization-log.json`
3. **"App is damaged and can't be opened"**: Ensure the app is properly signed with hardened runtime and notarized

4. **"Unable to locate certificate"**: The specified identity doesn't match any certificate in your keychain

### Verification

To verify app signing and notarization:

```bash
# Verify signing
codesign --verify --verbose=2 binary/CodeLooper.app

# Verify notarization stapling
stapler validate binary/CodeLooper.app
```

## Notes

- The notarization process typically takes 5-15 minutes
- Notarization is required for distribution outside the Mac App Store in macOS 10.15+
- Once notarized, the app can be distributed via direct download, auto-update mechanisms, or other channels
- The hardened runtime with proper entitlements is required for notarization
