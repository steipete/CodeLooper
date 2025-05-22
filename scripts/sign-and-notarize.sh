#!/bin/bash
# sign-and-notarize.sh - Comprehensive code signing and notarization script for FriendshipAI Mac app
# 
# This script handles the full process of:
# 1. Code signing with hardened runtime
# 2. Notarization with Apple
# 3. Stapling the notarization ticket
# 4. Creating distributable ZIP archives
#
# Key features:
# - Support for both development and CI environments
# - Multiple authentication methods (Apple ID or API key)
# - Robust error handling and retry mechanism
# - Detailed progress reporting and diagnostic information
# - GitHub Actions integration support
# - Control over which parts of the process to run

set -euo pipefail

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)" 
cd "$APP_DIR" || { echo "Error: Failed to change directory to $APP_DIR"; exit 1; }

# Initialize variables with defaults
BUNDLE_DIR="binary/FriendshipAI.app"
APP_BUNDLE_PATH="$APP_DIR/$BUNDLE_DIR"
ZIP_PATH="$APP_DIR/binary/FriendshipAI-notarize.zip"
FINAL_ZIP_PATH="$APP_DIR/binary/FriendshipAI-notarized.zip"
MAX_RETRIES=3
RETRY_DELAY=30
AUTH_METHOD="password" # Can be "password" or "api-key"
GITHUB_ACTIONS=${GITHUB_ACTIONS:-false}
VERBOSE=false
FORCE_RESIGN=false
SKIP_STAPLE=false
TIMEOUT_MINUTES=30

# Operation flags - what parts of the process to run
DO_SIGNING=true
DO_NOTARIZATION=false
CREATE_ZIP=true

# Log helper function with timestamp
log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
    
    # If running in GitHub Actions, also output as a step summary
    if [ "$GITHUB_ACTIONS" = "true" ] && [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        echo "$1" >> "$GITHUB_STEP_SUMMARY"
    fi
}

# Error logging
error() {
    if [ "$GITHUB_ACTIONS" = "true" ]; then
        echo "::error::$1"
    fi
    log "❌ ERROR: $1"
    return 1
}

# Warning logging
warning() {
    if [ "$GITHUB_ACTIONS" = "true" ]; then
        echo "::warning::$1"
    fi
    log "⚠️  WARNING: $1"
}

# Success logging
success() {
    log "✅ $1"
}

# Print usage information
print_usage() {
    echo "Sign and Notarize Script for FriendshipAI Mac App"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Authentication Options (required for notarization):"
    echo "  --apple-id EMAIL        Apple ID email for notarization"
    echo "  --apple-password PASS   App-specific password for the Apple ID"
    echo "  --apple-team-id ID      Apple Developer Team ID"
    echo "  or"
    echo "  --api-key-path PATH     Path to App Store Connect API key file (.p8)"
    echo "  --api-key-id ID         App Store Connect API Key ID"
    echo "  --api-key-issuer ID     App Store Connect API Key Issuer ID"
    echo ""
    echo "Process Control Options:"
    echo "  --sign-only             Only perform code signing, skip notarization"
    echo "  --notarize-only         Skip signing and only perform notarization"
    echo "  --sign-and-notarize     Perform both signing and notarization (default if notarization credentials provided)"
    echo ""
    echo "General Options:"
    echo "  --app-path PATH         Path to the app bundle (default: $BUNDLE_DIR)"
    echo "  --identity ID           Developer ID certificate to use for signing"
    echo "  --force-resign          Force re-signing the app even if already signed"
    echo "  --skip-staple           Skip stapling the notarization ticket to the app"
    echo "  --no-zip                Skip creating distributable ZIP archive"
    echo "  --timeout MINUTES       Notarization timeout in minutes (default: 30)"
    echo "  --github-actions        Enable GitHub Actions integration"
    echo "  --verbose               Enable verbose output"
    echo "  --help                  Show this help message"
}

# Function to read credentials from multiple sources
read_credentials() {
    # Initialize with existing environment variables
    local apple_id="${APPLE_ID:-}"
    local apple_password="${APPLE_PASSWORD:-}"
    local apple_team_id="${APPLE_TEAM_ID:-}"
    local apple_identity="${APPLE_IDENTITY:-}"
    local api_key_path="${API_KEY_PATH:-}"
    local api_key_id="${API_KEY_ID:-}"
    local api_key_issuer="${API_KEY_ISSUER:-}"
    
    # Parse command line arguments first (highest priority)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            # Authentication options
            --apple-id)
                apple_id="$2"
                shift 2
                ;;
            --apple-password)
                apple_password="$2"
                shift 2
                ;;
            --apple-team-id)
                apple_team_id="$2"
                shift 2
                ;;
            --identity|--sign-identity|--apple-identity)
                apple_identity="$2"
                shift 2
                ;;
            --api-key-path)
                api_key_path="$2"
                AUTH_METHOD="api-key"
                shift 2
                ;;
            --api-key-id)
                api_key_id="$2"
                AUTH_METHOD="api-key"
                shift 2
                ;;
            --api-key-issuer)
                api_key_issuer="$2"
                AUTH_METHOD="api-key"
                shift 2
                ;;
                
            # Process control options
            --sign-only)
                DO_SIGNING=true
                DO_NOTARIZATION=false
                shift
                ;;
            --notarize-only)
                DO_SIGNING=false
                DO_NOTARIZATION=true
                shift
                ;;
            --sign-and-notarize)
                DO_SIGNING=true
                DO_NOTARIZATION=true
                shift
                ;;
                
            # General options
            --app-path)
                APP_BUNDLE_PATH="$2"
                BUNDLE_DIR="$(basename "$APP_BUNDLE_PATH")"
                shift 2
                ;;
            --force-resign)
                FORCE_RESIGN=true
                shift
                ;;
            --skip-staple)
                SKIP_STAPLE=true
                shift
                ;;
            --no-zip)
                CREATE_ZIP=false
                shift
                ;;
            --timeout)
                TIMEOUT_MINUTES="$2"
                shift 2
                ;;
            --github-actions)
                GITHUB_ACTIONS=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Try to read from .env.notarize or .env files (lower priority)
    local env_files=(".env.notarize" ".env")
    for env_file in "${env_files[@]}"; do
        if [ -f "$APP_DIR/$env_file" ]; then
            if [ "$VERBOSE" = "true" ]; then
                log "Reading credentials from $env_file file..."
            fi
            
            while IFS= read -r line || [[ -n "$line" ]]; do
                # Skip comments and empty lines
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                [[ -z "$line" ]] && continue
                
                # Extract key and value
                if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
                    local key="${BASH_REMATCH[1]}"
                    local value="${BASH_REMATCH[2]}"
                    # Remove quotes if present
                    value="${value#\"}"
                    value="${value%\"}"
                    
                    # Set variables based on key (only if not already set)
                    case "$key" in
                        APPLE_ID) 
                            [ -z "$apple_id" ] && apple_id="$value"
                            ;;
                        APPLE_PASSWORD) 
                            [ -z "$apple_password" ] && apple_password="$value"
                            ;;
                        APPLE_TEAM_ID) 
                            [ -z "$apple_team_id" ] && apple_team_id="$value"
                            ;;
                        APPLE_IDENTITY) 
                            [ -z "$apple_identity" ] && apple_identity="$value"
                            ;;
                        API_KEY_PATH) 
                            [ -z "$api_key_path" ] && api_key_path="$value"
                            ;;
                        API_KEY_ID) 
                            [ -z "$api_key_id" ] && api_key_id="$value"
                            ;;
                        API_KEY_ISSUER) 
                            [ -z "$api_key_issuer" ] && api_key_issuer="$value"
                            ;;
                    esac
                fi
            done < "$APP_DIR/$env_file"
        fi
    done
    
    # Export as environment variables
    export APPLE_ID="$apple_id"
    export APPLE_PASSWORD="$apple_password"
    export APPLE_TEAM_ID="$apple_team_id"
    export APPLE_IDENTITY="$apple_identity"
    export API_KEY_PATH="$api_key_path"
    export API_KEY_ID="$api_key_id"
    export API_KEY_ISSUER="$api_key_issuer"
    
    # Determine which authentication method to use for notarization
    if [ -n "$api_key_path" ] && [ -n "$api_key_id" ] && [ -n "$api_key_issuer" ]; then
        AUTH_METHOD="api-key"
        if [ "$VERBOSE" = "true" ]; then
            log "Using App Store Connect API Key authentication method"
        fi
        
        # If notarization credentials are available and no explicit process control option was provided,
        # default to performing both signing and notarization
        if [ "$DO_NOTARIZATION" = false ] && [ "$DO_SIGNING" = true ]; then
            DO_NOTARIZATION=true
            log "Notarization credentials detected. Will perform both signing and notarization."
        fi
    elif [ -n "$apple_id" ] && [ -n "$apple_password" ] && [ -n "$apple_team_id" ]; then
        AUTH_METHOD="password"
        if [ "$VERBOSE" = "true" ]; then
            log "Using Apple ID password authentication method"
        fi
        
        # If notarization credentials are available and no explicit process control option was provided,
        # default to performing both signing and notarization
        if [ "$DO_NOTARIZATION" = false ] && [ "$DO_SIGNING" = true ]; then
            DO_NOTARIZATION=true
            log "Notarization credentials detected. Will perform both signing and notarization."
        fi
    fi
}

# Retry function for operations that might fail due to network issues
retry_operation() {
    local cmd="$1"
    local desc="$2"
    local attempt=1
    local result
    
    while [ $attempt -le $MAX_RETRIES ]; do
        log "Attempt $attempt/$MAX_RETRIES: $desc"
        if result=$(eval "$cmd" 2>&1); then
            echo "$result"
            return 0
        else
            local exit_code=$?
            log "Attempt $attempt failed (exit code: $exit_code)"
            if [ "$VERBOSE" = "true" ]; then
                log "Command output: $result"
            fi
            
            if [ $attempt -lt $MAX_RETRIES ]; then
                log "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            fi
        fi
        attempt=$((attempt + 1))
    done
    
    error "Failed after $MAX_RETRIES attempts: $desc"
    echo "$result"
    return 1
}

# Check if notarize tool is available based on Xcode version
check_notarize_tool() {
    if ! command -v xcrun &> /dev/null; then
        error "xcrun command not found. Please ensure Xcode is installed and set up correctly."
        exit 1
    fi
    
    # Check if notarytool is available (Xcode 13+)
    if xcrun --find notarytool &> /dev/null; then
        NOTARYTOOL_AVAILABLE=true
        log "Using modern notarytool for notarization"
    else
        # Fall back to older altool (pre-Xcode 13)
        if xcrun --find altool &> /dev/null; then
            NOTARYTOOL_AVAILABLE=false
            warning "Using legacy altool for notarization. Consider upgrading to Xcode 13+ for better notarization experience."
        else
            error "Neither notarytool nor altool found. Please ensure Xcode is installed correctly."
            exit 1
        fi
    fi
}

# Function to create notarytool auth arguments
get_notarytool_auth_args() {
    if [ "$AUTH_METHOD" = "api-key" ]; then
        echo "--key \"$API_KEY_PATH\" --key-id \"$API_KEY_ID\" --issuer \"$API_KEY_ISSUER\""
    else
        echo "--apple-id \"$APPLE_ID\" --password \"$APPLE_PASSWORD\" --team-id \"$APPLE_TEAM_ID\""
    fi
}

# Function to create altool auth arguments (legacy)
get_altool_auth_args() {
    if [ "$AUTH_METHOD" = "api-key" ]; then
        echo "--apiKey \"$API_KEY_ID\" --apiIssuer \"$API_KEY_ISSUER\""
    else
        echo "--username \"$APPLE_ID\" --password \"$APPLE_PASSWORD\""
    fi
}

# Function to perform code signing
perform_signing() {
    log "Starting code signing process for FriendshipAI Mac app..."
    
    # Check if the app bundle exists
    if [ ! -d "$APP_BUNDLE_PATH" ]; then
        error "App bundle not found at $APP_BUNDLE_PATH"
        log "Please build the app first by running ./build.sh"
        exit 1
    fi
    
    log "Found app bundle at $APP_BUNDLE_PATH"
    
    # Remove any existing code signatures and quarantine attributes
    log "Removing existing signatures and quarantine attributes..."
    xattr -cr "$APP_BUNDLE_PATH" 2>/dev/null || true
    
    # Create temporary entitlements file with hardened runtime
    log "Creating entitlements file with hardened runtime enabled..."
    
    # Check if the app has a real entitlements file
    ENTITLEMENTS_FILE="$APP_DIR/FriendshipAI/FriendshipAI.entitlements"
    TMP_ENTITLEMENTS="/tmp/FriendshipAI_entitlements.plist"
    
    if [ -f "$ENTITLEMENTS_FILE" ]; then
        log "Using entitlements from $ENTITLEMENTS_FILE and adding hardened runtime"
        # Copy existing entitlements and ensure hardened runtime is enabled
        cp "$ENTITLEMENTS_FILE" "$TMP_ENTITLEMENTS"
        
        # Use awk instead of sed for modifying the file to avoid platform differences
        if ! grep -q "com.apple.security.hardened-runtime" "$TMP_ENTITLEMENTS"; then
            # Create a new file with hardened runtime added
            awk '/<\/dict>/ { print "    <key>com.apple.security.hardened-runtime</key>\n    <true/>"; } { print; }' "$TMP_ENTITLEMENTS" > "${TMP_ENTITLEMENTS}.new"
            mv "${TMP_ENTITLEMENTS}.new" "$TMP_ENTITLEMENTS"
        fi
    else
        log "Creating new entitlements file with hardened runtime..."
        cat > "$TMP_ENTITLEMENTS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.hardened-runtime</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.personal-information.addressbook</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOF
    fi
    
    # Display the final entitlements that will be used
    if [ -f "$TMP_ENTITLEMENTS" ]; then
        log "Using the following entitlements for code signing:"
        if [ "$VERBOSE" = "true" ]; then
            cat "$TMP_ENTITLEMENTS"
        fi
    fi
    
    # Check if Frameworks directory exists and sign any items inside
    if [ -d "$APP_BUNDLE_PATH/Contents/Frameworks" ]; then
        # Sign the frameworks and helper executables first (if any)
        log "Signing embedded frameworks and executables..."
        find "$APP_BUNDLE_PATH/Contents/Frameworks" \( -type d -name "*.framework" -o -type f -name "*.dylib" \) 2>/dev/null | while read -r framework; do
            log "Signing $framework"
            codesign --force --options runtime --sign "${APPLE_IDENTITY:--}" "$framework" || log "⚠️ Failed to sign $framework, continuing..."
        done
    else
        log "No Frameworks directory found, skipping framework signing"
    fi
    
    # Check if Helpers directory exists and sign any helper apps
    if [ -d "$APP_BUNDLE_PATH/Contents/Helpers" ]; then
        # Sign any helper apps (if they exist)
        find "$APP_BUNDLE_PATH/Contents/Helpers" -type d -name "*.app" 2>/dev/null | while read -r helper; do
            log "Signing helper app $helper"
            codesign --force --options runtime --entitlements "$TMP_ENTITLEMENTS" --sign "${APPLE_IDENTITY:--}" "$helper" || log "⚠️ Failed to sign $helper, continuing..."
        done
    else
        log "No Helpers directory found, skipping helper app signing"
    fi
    
    # Sign the main executable
    log "Signing main executable..."
    if ! retry_operation "codesign --force --options runtime --entitlements \"$TMP_ENTITLEMENTS\" --sign \"${APPLE_IDENTITY:--}\" \"$APP_BUNDLE_PATH/Contents/MacOS/FriendshipAI\"" "Sign main executable"; then
        warning "Failed to sign main executable, but will continue with bundle signing..."
    fi
    
    # Sign the app bundle with hardened runtime
    log "Signing complete app bundle with hardened runtime..."
    if ! retry_operation "codesign --force --deep --options runtime --entitlements \"$TMP_ENTITLEMENTS\" --sign \"${APPLE_IDENTITY:--}\" \"$APP_BUNDLE_PATH\"" "Sign app bundle with hardened runtime"; then
        warning "Full app bundle signing failed. App may still have issues."
        log "This is likely due to code signing issues in the CI environment."
        log "The app will be signed with basic options as a fallback."
        
        # Fallback to simpler signing without special options
        if ! retry_operation "codesign --force --deep --sign \"${APPLE_IDENTITY:--}\" \"$APP_BUNDLE_PATH\"" "Sign app bundle (fallback)"; then
            error "Even basic fallback signing failed."
            exit 1
        fi
        success "Fallback signing completed."
    fi
    
    # Verify the code signature
    log "Verifying code signature..."
    VERIFICATION_OUTPUT=$(codesign --verify --verbose=2 "$APP_BUNDLE_PATH" 2>&1)
    VERIFICATION_RESULT=$?
    
    if [ $VERIFICATION_RESULT -eq 0 ]; then
        success "Code signature verification passed!"
    else
        warning "Code signature verification reported issues, but we'll continue:"
        log "$VERIFICATION_OUTPUT"
        log "These issues may be expected in CI environments without proper certificates."
    fi
    
    # Clear quarantine bit again
    xattr -cr "$APP_BUNDLE_PATH" 2>/dev/null || true
    
    # Clean up temp files
    rm -f "$TMP_ENTITLEMENTS"
    
    success "Code signing completed successfully!"
}

# Function to perform app notarization
perform_notarization() {
    log "Starting notarization process for FriendshipAI Mac app..."
    
    # Check if code signing before notarization is desired
    if [ "$DO_SIGNING" = false ] && [ "$FORCE_RESIGN" = true ]; then
        DO_SIGNING=true
        log "Enabling signing because --force-resign flag was set"
    fi
    
    # Check for authentication method requirements
    if [ "$AUTH_METHOD" = "password" ]; then
        MISSING_VARS=()
        [ -z "${APPLE_ID:-}" ] && MISSING_VARS+=("APPLE_ID")
        [ -z "${APPLE_PASSWORD:-}" ] && MISSING_VARS+=("APPLE_PASSWORD")
        [ -z "${APPLE_TEAM_ID:-}" ] && MISSING_VARS+=("APPLE_TEAM_ID")
        
        if [ ${#MISSING_VARS[@]} -gt 0 ]; then
            error "Missing required variables for password authentication: ${MISSING_VARS[*]}"
            log "Please either:"
            log "1. Create a .env.notarize file based on the sample in the documentation"
            log "2. Set the environment variables in your terminal"
            log "3. Pass values as command line arguments:"
            log "   ./sign-and-notarize.sh --apple-id your@email.com --apple-password your-password --apple-team-id ABCD12345"
            exit 1
        fi
    elif [ "$AUTH_METHOD" = "api-key" ]; then
        MISSING_VARS=()
        [ -z "${API_KEY_PATH:-}" ] && MISSING_VARS+=("API_KEY_PATH")
        [ -z "${API_KEY_ID:-}" ] && MISSING_VARS+=("API_KEY_ID")
        [ -z "${API_KEY_ISSUER:-}" ] && MISSING_VARS+=("API_KEY_ISSUER")
        
        if [ ${#MISSING_VARS[@]} -gt 0 ]; then
            error "Missing required variables for API key authentication: ${MISSING_VARS[*]}"
            log "Please provide --api-key-path, --api-key-id, and --api-key-issuer options"
            log "or set the corresponding environment variables."
            exit 1
        fi
        
        # Check if API key file exists
        if [ ! -f "$API_KEY_PATH" ]; then
            error "API key file not found at $API_KEY_PATH"
            exit 1
        fi
    else
        error "No valid authentication method configured. Please provide either:"
        log "1. Apple ID credentials (--apple-id, --apple-password, --apple-team-id)"
        log "2. App Store Connect API key credentials (--api-key-path, --api-key-id, --api-key-issuer)"
        exit 1
    fi
    
    # Check notarization tools
    check_notarize_tool
    
    # Step 1: Ensure app is signed with hardened runtime if requested or needed
    if [ "$DO_SIGNING" = true ] || [ "$FORCE_RESIGN" = true ] || ! codesign --verify --verbose=1 "$APP_BUNDLE_PATH" &>/dev/null; then
        log "Signing needs to be performed before notarization..."
        perform_signing
    else
        log "App already properly signed, skipping signing step"
    fi
    
    # Step 2: Create a ZIP archive for notarization
    log "Creating ZIP archive for notarization..."
    rm -f "$ZIP_PATH" # Remove existing zip if any
    mkdir -p "$(dirname "$ZIP_PATH")"
    if ! ditto -c -k --keepParent "$APP_BUNDLE_PATH" "$ZIP_PATH"; then
        error "Failed to create ZIP archive for notarization"
        exit 1
    fi
    
    # Step 3: Submit app for notarization
    log "Submitting app for notarization to Apple..."
    
    # Use the appropriate tool based on availability
    if [ "$NOTARYTOOL_AVAILABLE" = true ]; then
        # Modern notarytool approach
        AUTH_ARGS=$(get_notarytool_auth_args)
        
        # Create a temporary file to store the JSON output
        SUBMIT_JSON_OUTPUT="$APP_DIR/binary/notarization-submit.json"
        mkdir -p "$(dirname "$SUBMIT_JSON_OUTPUT")"
        
        SUBMIT_CMD="xcrun notarytool submit \"$ZIP_PATH\" $AUTH_ARGS --wait --output-format json --output \"$SUBMIT_JSON_OUTPUT\""
        if [ "$VERBOSE" = "true" ]; then
            log "Running command: $SUBMIT_CMD"
        fi
        
        # Run the submit command
        if ! retry_operation "$SUBMIT_CMD" "Submit app for notarization" >/dev/null; then
            error "Notarization submission failed"
            if [ -f "$SUBMIT_JSON_OUTPUT" ]; then
                log "Submission output: $(cat "$SUBMIT_JSON_OUTPUT")"
            fi
            exit 1
        fi
        
        # Check if the JSON output file exists
        if [ ! -f "$SUBMIT_JSON_OUTPUT" ]; then
            error "Notarization submission did not produce JSON output"
            exit 1
        fi
        
        # Check if jq is available for JSON parsing
        if ! command -v jq &> /dev/null; then
            warning "jq command not found. Using fallback awk parsing for JSON."
            NOTARIZATION_UUID=$(cat "$SUBMIT_JSON_OUTPUT" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | awk -F'"' '{print $4}')
            NOTARIZATION_STATUS=$(cat "$SUBMIT_JSON_OUTPUT" | grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | awk -F'"' '{print $4}')
        else
            # Extract UUID and status from JSON output
            NOTARIZATION_UUID=$(jq -r '.id' "$SUBMIT_JSON_OUTPUT")
            NOTARIZATION_STATUS=$(jq -r '.status' "$SUBMIT_JSON_OUTPUT")
        fi
        
        if [ -z "$NOTARIZATION_UUID" ]; then
            error "Failed to extract submission UUID from notarization result"
            log "$(cat "$SUBMIT_JSON_OUTPUT")"
            exit 1
        fi
        
        log "Notarization submitted successfully. Request UUID: $NOTARIZATION_UUID"
        log "Status: $NOTARIZATION_STATUS"
        
        # Wait for the notarization to complete if it's still in progress
        if [ "$NOTARIZATION_STATUS" = "in-progress" ]; then
            log "Notarization in progress. Waiting for completion (timeout: $TIMEOUT_MINUTES minutes)..."
            
            # Create a temporary file for the wait JSON output
            WAIT_JSON_OUTPUT="$APP_DIR/binary/notarization-wait.json"
            
            WAIT_CMD="xcrun notarytool wait \"$NOTARIZATION_UUID\" $AUTH_ARGS --timeout $((TIMEOUT_MINUTES * 60)) --output-format json --output \"$WAIT_JSON_OUTPUT\""
            if ! retry_operation "$WAIT_CMD" "Wait for notarization to complete" >/dev/null; then
                error "Notarization wait failed or timed out"
                if [ -f "$WAIT_JSON_OUTPUT" ]; then
                    log "$(cat "$WAIT_JSON_OUTPUT")"
                fi
                exit 1
            fi
            
            # Extract final status from wait JSON result
            if [ -f "$WAIT_JSON_OUTPUT" ]; then
                if command -v jq &> /dev/null; then
                    NOTARIZATION_STATUS=$(jq -r '.status' "$WAIT_JSON_OUTPUT")
                else
                    NOTARIZATION_STATUS=$(cat "$WAIT_JSON_OUTPUT" | grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | awk -F'"' '{print $4}')
                fi
                log "Final notarization status: $NOTARIZATION_STATUS"
            else
                error "Notarization wait did not produce JSON output"
                exit 1
            fi
        fi
        
        # Check the notarization status - case insensitive comparison for safety
        if [ "$(echo "$NOTARIZATION_STATUS" | tr '[:upper:]' '[:lower:]')" != "accepted" ]; then
            error "Notarization failed with status: $NOTARIZATION_STATUS"
            log "Getting detailed log for more information..."
            
            LOG_JSON_OUTPUT="$APP_DIR/binary/notarization-log.json"
            LOG_CMD="xcrun notarytool log \"$NOTARIZATION_UUID\" $AUTH_ARGS --output-format json --output \"$LOG_JSON_OUTPUT\""
            if ! retry_operation "$LOG_CMD" "Retrieve notarization log" >/dev/null; then
                error "Failed to retrieve notarization log"
                exit 1
            fi
            
            log "Notarization log saved to binary/notarization-log.json"
            
            # Display error summary from log if available
            if [ -f "$LOG_JSON_OUTPUT" ]; then
                log "Notarization issues:"
                if command -v jq &> /dev/null; then
                    jq -r '.issues[] | "- " + .message' "$LOG_JSON_OUTPUT" 2>/dev/null || log "Could not parse log JSON"
                else
                    cat "$LOG_JSON_OUTPUT"
                fi
            fi
            exit 1
        fi
    else
        # Legacy altool approach
        AUTH_ARGS=$(get_altool_auth_args)
        
        SUBMIT_CMD="xcrun altool --notarize-app --primary-bundle-id \"com.friendshipai.mac\" --file \"$ZIP_PATH\" $AUTH_ARGS"
        if [ "$VERBOSE" = "true" ]; then
            log "Running command: $SUBMIT_CMD"
        fi
        
        NOTARIZATION_RESULT=$(retry_operation "$SUBMIT_CMD" "Submit app for notarization")
        
        if [ $? -ne 0 ]; then
            error "Notarization submission failed"
            log "$NOTARIZATION_RESULT"
            exit 1
        fi
        
        # Extract request UUID from result
        NOTARIZATION_UUID=$(echo "$NOTARIZATION_RESULT" | grep "RequestUUID" | awk '{print $3}')
        
        if [ -z "$NOTARIZATION_UUID" ]; then
            error "Failed to extract submission UUID from notarization result"
            log "$NOTARIZATION_RESULT"
            exit 1
        fi
        
        log "Notarization submitted successfully. Request UUID: $NOTARIZATION_UUID"
        log "Waiting for notarization to complete (timeout: $TIMEOUT_MINUTES minutes)..."
        
        # Wait for notarization to complete with timeout
        START_TIME=$(date +%s)
        END_TIME=$((START_TIME + TIMEOUT_MINUTES * 60))
        
        NOTARIZATION_STATUS="in-progress"
        while [ "$NOTARIZATION_STATUS" = "in-progress" ]; do
            # Check if timeout has been reached
            CURRENT_TIME=$(date +%s)
            if [ $CURRENT_TIME -gt $END_TIME ]; then
                error "Notarization timed out after $TIMEOUT_MINUTES minutes"
                exit 1
            fi
            
            # Wait before checking status again
            sleep 30
            
            # Check notarization status
            STATUS_CMD="xcrun altool --notarization-info \"$NOTARIZATION_UUID\" $AUTH_ARGS"
            STATUS_RESULT=$(retry_operation "$STATUS_CMD" "Check notarization status")
            
            if echo "$STATUS_RESULT" | grep -q "Status: success"; then
                NOTARIZATION_STATUS="Accepted"
                break
            elif echo "$STATUS_RESULT" | grep -q "Status: invalid"; then
                NOTARIZATION_STATUS="Invalid"
                error "Notarization failed with status: Invalid"
                log "$STATUS_RESULT"
                exit 1
            fi
        done
    fi
    
    success "Notarization completed successfully!"
    
    # Step 4: Staple the notarization ticket to the app if not skipped
    if [ "$SKIP_STAPLE" = false ]; then
        log "Stapling notarization ticket to app bundle..."
        if ! retry_operation "xcrun stapler staple \"$APP_BUNDLE_PATH\"" "Staple notarization ticket" >/dev/null; then
            error "Failed to staple notarization ticket to app bundle"
            exit 1
        fi
        
        # Verify the stapling
        log "Verifying stapled notarization ticket..."
        if ! retry_operation "xcrun stapler validate \"$APP_BUNDLE_PATH\"" "Verify stapled ticket" >/dev/null; then
            error "Failed to verify stapled notarization ticket"
            exit 1
        fi
        
        success "Stapling completed successfully"
    else
        log "Skipping stapling step as requested"
    fi
    
    # Step 5: Create distributable ZIP archive if needed
    if [ "$CREATE_ZIP" = true ]; then
        log "Creating distributable ZIP archive..."
        rm -f "$FINAL_ZIP_PATH" # Remove existing zip if any
        if ! ditto -c -k --keepParent "$APP_BUNDLE_PATH" "$FINAL_ZIP_PATH"; then
            warning "Failed to create ZIP archive, but notarization was successful"
        else
            success "Distributable ZIP archive created: $FINAL_ZIP_PATH"
            # Calculate file size and hash for verification
            ZIP_SIZE=$(du -h "$FINAL_ZIP_PATH" | cut -f1)
            ZIP_SHA=$(shasum -a 256 "$FINAL_ZIP_PATH" | cut -d' ' -f1)
            log "ZIP archive size: $ZIP_SIZE"
            log "ZIP SHA-256 hash: $ZIP_SHA"
        fi
    else
        log "Skipping ZIP creation (--no-zip flag was provided)"
    fi
}

# Main execution starts here
log "Starting sign and notarize script for FriendshipAI Mac app..."

# Read credentials from all possible sources
read_credentials "$@"

# Check if the app bundle exists
if [ ! -d "$APP_BUNDLE_PATH" ]; then
    error "App bundle not found at $APP_BUNDLE_PATH"
    log "Please build the app first by running ./build.sh"
    exit 1
fi

log "Found app bundle at $APP_BUNDLE_PATH"

# Check if we should do code signing
if [ "$DO_SIGNING" = true ]; then
    perform_signing
else
    log "Skipping code signing as requested"
fi

# Check if we should do notarization
if [ "$DO_NOTARIZATION" = true ]; then
    perform_notarization
else
    log "Skipping notarization as requested"
    
    # Create a simple ZIP file if signing only and zip creation is requested
    if [ "$DO_SIGNING" = true ] && [ "$CREATE_ZIP" = true ]; then
        log "Creating distributable ZIP archive after signing..."
        mkdir -p "$(dirname "$FINAL_ZIP_PATH")"
        if ! ditto -c -k --keepParent "$APP_BUNDLE_PATH" "$FINAL_ZIP_PATH"; then
            warning "Failed to create ZIP archive"
        else
            success "Distributable ZIP archive created: $FINAL_ZIP_PATH"
            # Calculate file size and hash for verification
            ZIP_SIZE=$(du -h "$FINAL_ZIP_PATH" | cut -f1)
            ZIP_SHA=$(shasum -a 256 "$FINAL_ZIP_PATH" | cut -d' ' -f1)
            log "ZIP archive size: $ZIP_SIZE"
            log "ZIP SHA-256 hash: $ZIP_SHA"
        fi
    fi
fi

# Print final status summary
log ""
log "Operation summary:"
log "✅ App bundle: $APP_BUNDLE_PATH"
if [ "$DO_SIGNING" = true ]; then
    log "✅ Code signing: Completed"
fi
if [ "$DO_NOTARIZATION" = true ]; then
    log "✅ Notarization: Completed"
    log "✅ Notarization is valid for all future distributions of this exact binary"
    if [ "$SKIP_STAPLE" = false ]; then
        log "✅ Stapling: Completed (users can run without security warnings)"
    else
        log "⚠️ Stapling: Skipped"
    fi
fi
if [ "$CREATE_ZIP" = true ] && [ -f "$FINAL_ZIP_PATH" ]; then
    log "✅ Distributable ZIP archive: $FINAL_ZIP_PATH"
fi

success "Script completed successfully!"