# CodeLooper CI/CD Workflows

This directory contains GitHub Actions workflows for CodeLooper.

## Workflows

### `build-mac-app.yml`
Builds, signs, and optionally notarizes the CodeLooper macOS application.

**Triggers:**
- Pull requests that modify Swift source code, resources, or build scripts
- Manual workflow dispatch with options for notarization and releases

**Features:**
- Automatic build caching for Swift packages and build artifacts
- Code signing with P12 certificates
- Apple notarization using App Store Connect API
- DMG creation for distribution
- Artifact uploads for download
- PR comments with build status

## Required Secrets

To enable full CI functionality, configure these repository secrets:

### Code Signing
- `MACOS_SIGNING_CERTIFICATE_P12_BASE64`: Base64-encoded P12 certificate for code signing
- `MACOS_SIGNING_CERTIFICATE_PASSWORD`: Password for the P12 certificate

### Notarization
- `APP_STORE_CONNECT_API_KEY_P8`: App Store Connect API key (.p8 file contents)
- `APP_STORE_CONNECT_KEY_ID`: App Store Connect API key ID
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect issuer ID

## Local Development

You can run the build scripts locally:

```bash
# Build only
./build.sh

# Build and sign (requires certificates)
./scripts/build-and-notarize.sh --skip-notarization

# Full build, sign, and notarize
./scripts/build-and-notarize.sh --create-dmg
```

## Artifacts

Successful builds produce:
- `CodeLooper.app` - The application bundle
- `CodeLooper-macOS-{version}.zip` - Compressed app bundle
- `CodeLooper-macOS-{version}.dmg` - Disk image for distribution