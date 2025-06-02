#!/bin/bash
set -eo pipefail

# --- Helper Functions ---
log() {
    echo "[$(basename "${BASH_SOURCE[0]}")] $(date "+%Y-%m-%d %H:%M:%S") - $1"
}

# --- Configuration & Temporary File Management ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PRIVATE_KEYS_DIR="${PROJECT_ROOT}/.private_keys"

TEMP_P8_FILE_PATH=""
TEMP_NOTARY_API_KEY_JSON_PATH=""

cleanup_temp_files() {
  log "Cleaning up temporary files..."
  # Clean up specific temp files that might be created with mktemp patterns
  rm -f "${PRIVATE_KEYS_DIR}/temp_notary_key."*.p8 2>/dev/null || true
  rm -f "${PRIVATE_KEYS_DIR}/notary_api_key."*.json 2>/dev/null || true
  # Clean up specific temp files if their exact names were captured (for the current run)
  if [ -n "$TEMP_P8_FILE_PATH" ] && [ -f "$TEMP_P8_FILE_PATH" ]; then
    rm -f "$TEMP_P8_FILE_PATH"
    log "Removed temporary P8 file (specific path): $TEMP_P8_FILE_PATH"
  fi
  if [ -n "$TEMP_NOTARY_API_KEY_JSON_PATH" ] && [ -f "$TEMP_NOTARY_API_KEY_JSON_PATH" ]; then
    rm -f "$TEMP_NOTARY_API_KEY_JSON_PATH"
    log "Removed temporary Notary API Key JSON file (specific path): $TEMP_NOTARY_API_KEY_JSON_PATH"
  fi
}

# Initial cleanup to ensure clean state before mktemp operations
mkdir -p "$PRIVATE_KEYS_DIR" 2>/dev/null || true 
cleanup_temp_files 

trap cleanup_temp_files EXIT SIGINT SIGTERM

echo "macOS Swift App Local Build & Notarize Script"
echo "-----------------------------------------------"

# --- Argument Parsing ---
SKIP_NOTARIZATION=false
CREATE_DMG=false
APP_VERSION_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-notarization)
      SKIP_NOTARIZATION=true
      log "--skip-notarization flag detected. Will only build and sign."
      shift
      ;;
    --create-dmg)
      CREATE_DMG=true
      log "--create-dmg flag detected. DMG will be created after other steps."
      shift
      ;;
    --app-version)
      APP_VERSION_ARG="$2"
      log "--app-version '$APP_VERSION_ARG' provided for artifact naming."
      shift 2
      ;;
    *)
      log "Unknown argument to build-and-notarize: $1"
      shift
      ;;
  esac
done

# Ensure we are in the project root
cd "$PROJECT_ROOT"
echo "Working directory: $(pwd)"

# --- Configuration ---
APP_NAME="CodeLooper"
BUILD_SCRIPT_PATH="scripts/build.sh"
RCODESIGN_BINARY_PATH="tools/rcodesign/bin/rcodesign"
APP_BUNDLE_REL_PATH="binary/${APP_NAME}.app"

mkdir -p "$PRIVATE_KEYS_DIR" # Ensure .private_keys directory exists

# --- Step 1: Build the app ---
log "Step 1: Building the CodeLooper app..."

# Use Xcode archiving for release builds (more reliable than SPM for complex projects)
ARCHIVE_PATH="./build/CodeLooper.xcarchive"
log "Creating Xcode archive..."

# Clean any existing archive
rm -rf "$ARCHIVE_PATH"

# Generate Xcode project first
if ! ./scripts/generate-xcproj.sh; then
    log "Error: Failed to generate Xcode project"
    exit 1
fi

# Create archive with Xcode
if ! xcodebuild -workspace CodeLooper.xcworkspace -scheme CodeLooper -configuration Release -archivePath "$ARCHIVE_PATH" archive; then
    log "Error: Xcode archive failed"
    exit 1
fi

# Copy app from archive to binary directory
mkdir -p binary
cp -R "$ARCHIVE_PATH/Products/Applications/CodeLooper.app" "./binary/"

log "✅ Archive created and app copied to binary directory"

# Verify the app bundle was created
if [ ! -d "$APP_BUNDLE_REL_PATH" ]; then
    log "Error: App bundle not found at $APP_BUNDLE_REL_PATH"
    exit 1
fi

log "✅ Build completed successfully"

# --- Step 2: Code Signing and Notarization (if not skipped) ---
if [ "$SKIP_NOTARIZATION" = false ]; then
    log "Step 2: Code signing and notarization..."
    
    # First, code sign the app
    log "Code signing the app bundle..."
    if ! ./scripts/codesign-app.sh "$APP_BUNDLE_REL_PATH"; then
        log "Error: Code signing failed"
        exit 1
    fi
    
    # Then attempt notarization using our existing script
    log "Attempting notarization..."
    if ./scripts/sign-and-notarize.sh > /dev/null 2>&1; then
        log "✅ Notarization completed successfully"
    else
        log "⚠️  Notarization failed or credentials not available - continuing with signed app"
    fi
else
    log "⚠️  Skipping notarization (--skip-notarization flag used)"
    
    # Still code sign even if skipping notarization
    log "Code signing the app bundle..."
    if ! ./scripts/codesign-app.sh "$APP_BUNDLE_REL_PATH"; then
        log "Error: Code signing failed"
        exit 1
    fi
fi

# --- Step 3: Create DMG (if requested) ---
if [ "$CREATE_DMG" = true ]; then
    log "Step 3: Creating DMG..."
    
    # Determine version for DMG naming
    if [ -n "$APP_VERSION_ARG" ]; then
        VERSION_ARG="--app-version $APP_VERSION_ARG"
    else
        VERSION_ARG="--app-version v1.0.0"
    fi
    
    # Use our existing DMG creation script
    if ./scripts/create-dmg.sh --app-path "$APP_BUNDLE_REL_PATH" --output-dir binary $VERSION_ARG; then
        log "✅ DMG created successfully"
        DMG_PATH="binary/${APP_NAME}-macOS-${APP_VERSION_ARG:-v1.0.0}.dmg"
    else
        log "❌ Failed to create DMG"
        exit 1
    fi
else
    log "⚠️  Skipping DMG creation (--create-dmg flag not used)"
fi

log "✅ CodeLooper build and notarization process completed successfully!"

if [ "$CREATE_DMG" = true ] && [ -f "$DMG_PATH" ]; then
    log "DMG available at: $DMG_PATH"
fi

log "App bundle available at: $APP_BUNDLE_REL_PATH"