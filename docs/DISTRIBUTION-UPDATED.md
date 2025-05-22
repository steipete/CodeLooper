# Mac App Distribution Guide

This document explains the process for building, signing, notarizing and distributing the CodeLooper Mac app.

## Overview

The Mac app distribution process involves several steps:

1. **Build**: Compiling the app using Xcode
2. **Sign**: Code signing with hardened runtime
3. **Notarize**: Submitting to Apple for notarization and stapling the ticket
4. **Package**: Creating distributable DMG and ZIP files

## Consolidated Script

We've consolidated the app signing and notarization into a single script: `sign-and-notarize.sh`. This script handles all aspects of the app distribution process after building.

### Usage

```bash
cd mac
./scripts/sign-and-notarize.sh [options]
```

### Common Usage Patterns

1. **Sign only** (for development and testing):

   ```bash
   ./scripts/sign-and-notarize.sh --sign-only --no-zip
   ```

2. **Sign and notarize** (for distribution):

   ```bash
   ./scripts/sign-and-notarize.sh --apple-id "your@email.com" --apple-password "app-specific-password" --apple-team-id "TEAMID" --identity "Developer ID Application: Your Name (TEAMID)"
   ```

3. **Notarize only** (if app is already signed):
   ```bash
   ./scripts/sign-and-notarize.sh --notarize-only --apple-id "your@email.com" --apple-password "app-specific-password" --apple-team-id "TEAMID"
   ```

### Options

Run `./scripts/sign-and-notarize.sh --help` to see all available options, including:

- Authentication options for notarization
- Process control options to specify which parts of the process to run
- General options such as paths, timeouts, and flags

## CI/CD Integration

The GitHub Actions workflow uses this script to sign and notarize the app during PR builds and releases. It's configurable via workflow inputs to control whether notarization is performed.

## Troubleshooting

If you encounter issues during the signing or notarization process:

1. **Code signing issues**:

   - Ensure you have a valid Developer ID certificate in your keychain
   - Check that the app's entitlements are properly configured
   - Use the `--force-resign` flag to force re-signing

2. **Notarization issues**:

   - Validate your Apple ID credentials and team ID
   - Check the notarization log for specific errors
   - Ensure the app meets Apple's requirements for notarization

3. **Distribution issues**:
   - Verify that the notarization was stapled to the app
   - Test the app by downloading it from a web browser to ensure Gatekeeper recognizes it
   - Use `xcrun stapler validate /path/to/CodeLooper.app` to verify stapling

## Distributable Files

The script creates the following files in the `mac/binary/` directory:

- `CodeLooper.app`: The signed and (optionally) notarized app bundle
- `CodeLooper-notarized.zip`: The notarized ZIP archive (if notarization was performed)
- `CodeLooper.zip`: A signed but not notarized ZIP archive (if notarization was skipped)

The DMG creation is handled separately by the `create-dmg.sh` script in CI.
EOF < /dev/null
