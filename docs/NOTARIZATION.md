# Mac App Notarization Workflow

This document explains the Mac app notarization workflow for CodeLooper, including how we've consolidated the process to prevent double-zipping issues.

> **Important**: We now use a consolidated script `sign-and-notarize.sh` instead of separate scripts. See [DISTRIBUTION-UPDATED.md](./DISTRIBUTION-UPDATED.md) for detailed usage information.

## Overview

The Mac app build, signing, and notarization process follows these steps:

1. **Build**: Compile the app using Xcode
2. **Sign**: Code sign the app with hardened runtime
3. **Notarize**: Submit to Apple for notarization and staple the ticket
4. **Package**: Create distributable DMG and ZIP files

## Consolidated Approach

Previously, the build pipeline created ZIP files at multiple stages, which could result in double-zipped files:

- `codesign-app.sh` created ZIPs for ad-hoc distribution
- `notarize-mac.sh` created ZIPs for notarization
- The GitHub workflow created a final versioned ZIP

To resolve this issue, we've consolidated the process into a single script that handles the entire signing and notarization workflow:

1. Created a new consolidated script `sign-and-notarize.sh` that handles both signing and notarization
2. Added process control flags (`--sign-only`, `--notarize-only`, `--sign-and-notarize`)
3. Implemented a consistent `--no-zip` flag to control ZIP creation in one place
4. Updated the GitHub workflow to use this consolidated script

## Workflow Sequence

1. The Mac app is built using `build.sh`
2. The app is processed by the consolidated `sign-and-notarize.sh` script, which:
   - Signs the app with hardened runtime
   - Notarizes with Apple (if credentials are provided)
   - Creates a single notarized ZIP file
3. The final step in the workflow uses the notarized ZIP for distribution

## Related Files

- `.github/workflows/mac-build-notarize.yml`: Main workflow file
- `mac/scripts/sign-and-notarize.sh`: Consolidated signing and notarization script
- `mac/scripts/create-dmg.sh`: DMG creation script
- `mac/scripts/post-binary-info.sh`: PR comment generation script
- `mac/docs/DISTRIBUTION-UPDATED.md`: Detailed documentation on the distribution process
