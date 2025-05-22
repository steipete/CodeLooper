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

# Determine build arguments based on signing availability
BUILD_ARGS=""

# Check for P12 certificate (from environment or file)
if [ -n "${MACOS_SIGNING_P12_FILE_PATH:-}" ] && [ -f "${MACOS_SIGNING_P12_FILE_PATH}" ]; then
    log "P12 certificate found at $MACOS_SIGNING_P12_FILE_PATH"
    BUILD_ARGS="--p12-file $MACOS_SIGNING_P12_FILE_PATH"
    
    if [ -n "${MACOS_SIGNING_CERTIFICATE_PASSWORD:-}" ]; then
        BUILD_ARGS="$BUILD_ARGS --p12-password $MACOS_SIGNING_CERTIFICATE_PASSWORD"
    else
        log "Warning: P12 file found but no password provided"
    fi
else
    log "No P12 certificate available - will try system keychain signing"
fi

# Execute build script
if ! bash "$BUILD_SCRIPT_PATH" $BUILD_ARGS; then
    log "Error: Build script failed"
    exit 1
fi

# Verify the app bundle was created
if [ ! -d "$APP_BUNDLE_REL_PATH" ]; then
    log "Error: App bundle not found at $APP_BUNDLE_REL_PATH"
    exit 1
fi

log "✅ Build completed successfully"

# --- Step 2: Notarization (if not skipped) ---
if [ "$SKIP_NOTARIZATION" = false ]; then
    log "Step 2: Attempting notarization..."
    
    # Check if we have the required environment variables for notarization
    if [ -n "${APP_STORE_CONNECT_P8_FILE_PATH:-}" ] && [ -f "${APP_STORE_CONNECT_P8_FILE_PATH}" ] && \
       [ -n "${APP_STORE_CONNECT_KEY_ID:-}" ] && [ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]; then
        
        log "Notarization credentials found, proceeding with notarization..."
        
        # Download rcodesign if not available
        if [ ! -f "$RCODESIGN_BINARY_PATH" ]; then
            log "Downloading rcodesign..."
            mkdir -p "$(dirname "$RCODESIGN_BINARY_PATH")"
            
            # Download rcodesign (adjust URL/version as needed)
            RCODESIGN_URL="https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign%2F0.22.0/apple-codesign-0.22.0-macos-universal.tar.gz"
            curl -L "$RCODESIGN_URL" | tar -xz -C "$(dirname "$RCODESIGN_BINARY_PATH")" --strip-components=1
            chmod +x "$RCODESIGN_BINARY_PATH"
        fi
        
        # Submit for notarization
        log "Submitting $APP_BUNDLE_REL_PATH for notarization..."
        "$RCODESIGN_BINARY_PATH" notary-submit \
            --api-key-path "${APP_STORE_CONNECT_P8_FILE_PATH}" \
            --api-issuer "${APP_STORE_CONNECT_ISSUER_ID}" \
            --api-key "${APP_STORE_CONNECT_KEY_ID}" \
            --wait \
            "$APP_BUNDLE_REL_PATH"
        
        if [ $? -eq 0 ]; then
            log "✅ Notarization completed successfully"
        else
            log "❌ Notarization failed"
            exit 1
        fi
    else
        log "⚠️  Notarization credentials not available - skipping notarization"
    fi
else
    log "⚠️  Skipping notarization (--skip-notarization flag used)"
fi

# --- Step 3: Create DMG (if requested) ---
if [ "$CREATE_DMG" = true ]; then
    log "Step 3: Creating DMG..."
    
    # Determine DMG name
    if [ -n "$APP_VERSION_ARG" ]; then
        DMG_NAME="${APP_NAME}-macOS-${APP_VERSION_ARG}.dmg"
    else
        DMG_NAME="${APP_NAME}-macOS.dmg"
    fi
    
    DMG_PATH="artifacts/$DMG_NAME"
    mkdir -p artifacts
    
    # Create DMG using hdiutil
    TEMP_DMG_DIR="temp_dmg_$$"
    mkdir -p "$TEMP_DMG_DIR"
    
    # Copy app to temp directory
    cp -R "$APP_BUNDLE_REL_PATH" "$TEMP_DMG_DIR/"
    
    # Create DMG
    log "Creating DMG: $DMG_PATH"
    hdiutil create -volname "$APP_NAME" -srcfolder "$TEMP_DMG_DIR" -ov -format UDZO "$DMG_PATH"
    
    # Clean up temp directory
    rm -rf "$TEMP_DMG_DIR"
    
    if [ -f "$DMG_PATH" ]; then
        log "✅ DMG created successfully: $DMG_PATH"
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