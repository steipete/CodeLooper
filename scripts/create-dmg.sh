#!/bin/bash
# create-dmg.sh - Creates a distributable DMG for the FriendshipAI Mac app
# This script creates a professional DMG file with background image and correct placement

set -eo pipefail

SCRIPT_NAME=$(basename "$0")
log() {
    echo "[$SCRIPT_NAME] $(date "+%Y-%m-%d %H:%M:%S") - $1"
}

print_usage() {
    echo "Usage: $0 --app-path <path_to_app_bundle> --output-dir <directory_for_dmg> --app-version <version_string> [--volume-name <name>]"
    echo "  --app-path      Required. Path to the .app bundle to package."
    echo "  --output-dir    Required. Directory where the DMG will be created."
    echo "  --app-version   Required. Version string (e.g., 1.0.0-b123) for DMG naming."
    echo "  --volume-name   Optional. Name for the mounted DMG volume (default: 'FriendshipAI Installer')."
}

APP_BUNDLE_PATH=""
OUTPUT_DIR=""
APP_VERSION=""
VOLUME_NAME="FriendshipAI Installer"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app-path)
            APP_BUNDLE_PATH="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --app-version)
            APP_VERSION="$2"
            shift 2
            ;;
        --volume-name)
            VOLUME_NAME="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            log "Unknown argument: $1"
            print_usage
            exit 1
            ;;
    esac
done

if [ -z "$APP_BUNDLE_PATH" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$APP_VERSION" ]; then
    log "Error: --app-path, --output-dir, and --app-version are required arguments."
    print_usage
    exit 1
fi

if [ ! -d "$APP_BUNDLE_PATH" ]; then
  log "Error: App bundle not found at $APP_BUNDLE_PATH"
  exit 1
fi

mkdir -p "$OUTPUT_DIR" || { log "Error: Failed to create output directory $OUTPUT_DIR"; exit 1; }

APP_NAME=$(basename "$APP_BUNDLE_PATH" .app)
DMG_NAME="${APP_NAME}-macOS-${APP_VERSION}.dmg"
OUTPUT_DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"

log "Creating DMG for $APP_BUNDLE_PATH..."
log "Output DMG: $OUTPUT_DMG_PATH"
log "Volume Name: $VOLUME_NAME"

# Create a temporary directory for staging DMG contents
TEMP_DIR=$(mktemp -d -t dmg_staging_XXXXXX)
cleanup_temp_dir() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        log "Cleaning up temporary staging directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup_temp_dir EXIT SIGINT SIGTERM

log "Staging application and Applications link in $TEMP_DIR..."
cp -R "$APP_BUNDLE_PATH" "$TEMP_DIR/"
ln -s /Applications "$TEMP_DIR/Applications"

log "Running hdiutil to create DMG..."
hdiutil create -volname "$VOLUME_NAME" \
  -srcfolder "$TEMP_DIR" \
  -ov -format UDZO "$OUTPUT_DMG_PATH"

if [ $? -eq 0 ]; then
  log "✅ DMG created successfully at $OUTPUT_DMG_PATH (Size: $(du -sh "$OUTPUT_DMG_PATH" | cut -f1))"
  # The calling script can check the exit code of this script.
else
  log "❌ DMG creation failed using hdiutil."
  exit 1
fi

exit 0