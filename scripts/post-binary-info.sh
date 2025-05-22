#!/bin/bash
# post-binary-info.sh - Post compiled binary information to a PR comment
# 
# This script collects information about the compiled Mac binary and posts it
# as a comment to a GitHub PR. Information includes:
# - Binary size
# - Compilation date
# - Download link
# - Build status (success or error)

set -euo pipefail

# Get script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." &> /dev/null && pwd)"
MAC_DIR="$REPO_ROOT/mac"
CI_ARTIFACTS_DIR="$REPO_ROOT/ci-artifacts"

# Parse command line arguments
EXPLICIT_PR_NUMBER=""
EXPLICIT_ARTIFACT_URL=""
EXPLICIT_VERSION=""
BUILD_STATUS="success"
ERROR_MESSAGE=""
VERBOSE="false"  # Initialize VERBOSE variable
SIGN_TYPE=""     # Type of signing: notarized, adhoc, minimal

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr-number)
            EXPLICIT_PR_NUMBER="$2"
            shift 2
            ;;
        --artifact-url)
            EXPLICIT_ARTIFACT_URL="$2"
            shift 2
            ;;
        --version)
            EXPLICIT_VERSION="$2"
            shift 2
            ;;
        --sign-type)
            SIGN_TYPE="$2"
            shift 2
            ;;
        --error)
            BUILD_STATUS="error"
            if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                ERROR_MESSAGE="$2"
                shift 2
            else
                ERROR_MESSAGE="Build failed with an unknown error"
                shift
            fi
            ;;
        *)  # Unknown option
            shift
            ;;
    esac
done

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Please install it: https://cli.github.com/manual/installation"
    exit 1
fi

# Function to get binary path - checks multiple locations
get_binary_path() {
    local binary_paths=(
        "$MAC_DIR/binary/FriendshipAI.app/Contents/MacOS/FriendshipAI"
        "$CI_ARTIFACTS_DIR/FriendshipAI.app/Contents/MacOS/FriendshipAI"
        "$CI_ARTIFACTS_DIR/*/Contents/MacOS/FriendshipAI"
    )
    
    for path_pattern in "${binary_paths[@]}"; do
        # Use find to support patterns with wildcards
        found_path=$(find $(dirname "$path_pattern") -path "$(basename "$path_pattern")" -type f 2>/dev/null | head -n 1)
        if [[ -n "$found_path" ]]; then
            echo "$found_path"
            return 0
        elif [[ -f "$path_pattern" ]]; then
            # Direct match without wildcards
            echo "$path_pattern"
            return 0
        fi
    done
    
    if [[ "$BUILD_STATUS" == "error" ]]; then
        # Don't fail when in error state, just return empty
        return 0
    else
        echo "Error: Could not find Mac binary in any expected location" >&2
        exit 1
    fi
}

# Function to get app bundle path
get_app_bundle_path() {
    local app_bundle_paths=(
        "$MAC_DIR/binary/FriendshipAI.app"
        "$REPO_ROOT/artifacts/FriendshipAI.app"
        "$CI_ARTIFACTS_DIR/FriendshipAI.app"
        "$CI_ARTIFACTS_DIR/*/FriendshipAI.app"
        "$CI_ARTIFACTS_DIR/FriendshipAI-macOS-*"
        "$(pwd)/mac/binary/FriendshipAI.app"
        "$(pwd)/artifacts/FriendshipAI.app"
    )
    
    for path_pattern in "${app_bundle_paths[@]}"; do
        # Use find to support patterns with wildcards
        if [[ "$path_pattern" == *"*"* ]]; then
            # Pattern contains wildcards, use find
            base_dir=$(dirname "$path_pattern")
            pattern=$(basename "$path_pattern")
            found_path=$(find "$base_dir" -name "$pattern" -type d 2>/dev/null | head -n 1)
            if [[ -n "$found_path" ]]; then
                echo "$found_path"
                return 0
            fi
        elif [[ -d "$path_pattern" ]]; then
            # Direct match without wildcards
            echo "$path_pattern"
            return 0
        fi
    done
    
    if [[ "$BUILD_STATUS" == "error" ]]; then
        # Don't fail when in error state, just return empty
        return 0
    else
        echo "Error: Could not find app bundle in any expected location" >&2
        exit 1
    fi
}

# Function to get PR number - either from parameter or from current branch
get_pr_number() {
    # First check if PR_NUMBER is provided as environment variable
    if [[ -n "${PR_NUMBER:-}" ]]; then
        echo "$PR_NUMBER"
        return 0
    fi
    
    # Next check if --pr-number flag was provided
    if [[ -n "${EXPLICIT_PR_NUMBER:-}" ]]; then
        echo "$EXPLICIT_PR_NUMBER"
        return 0
    fi
    
    # Otherwise, determine from current branch
    local current_branch=$(git branch --show-current)
    
    if [[ -z "$current_branch" ]]; then
        echo "Error: Not on a branch and no PR number provided" >&2
        exit 1
    fi
    
    # Try to get PR number from current branch
    local pr_num=$(gh pr list --head "$current_branch" --state open --json number --jq '.[0].number')
    
    if [[ -z "$pr_num" ]]; then
        echo "Error: No open PR found for branch $current_branch" >&2
        exit 1
    fi
    
    echo "$pr_num"
}

# Function to format size in a human-readable way
format_size() {
    local size_bytes=$1
    
    if [[ $size_bytes -lt 1024 ]]; then
        echo "${size_bytes} B"
    elif [[ $size_bytes -lt 1048576 ]]; then
        echo "$(( (size_bytes * 10) / 1024 ))KB" | sed 's/\(.*\)\(.\)$/\1.\2/'
    else
        echo "$(( (size_bytes * 10) / 1048576 ))MB" | sed 's/\(.*\)\(.\)$/\1.\2/'
    fi
}

# Main execution
main() {
    echo "Collecting Mac binary information..."
    
    # Get PR number for comment identification
    PR_NUMBER=$(get_pr_number)
    echo "Target PR: #$PR_NUMBER"
    
    if [[ "$BUILD_STATUS" == "success" ]]; then
        echo "Building success comment..."
        
        # Get binary path and check if it exists
        BINARY_PATH=$(get_binary_path)
        APP_BUNDLE_PATH=$(get_app_bundle_path)
        
        echo "Found binary at: $BINARY_PATH"
        echo "Found app bundle at: $APP_BUNDLE_PATH"
        
        # Get binary size
        BINARY_SIZE=$(stat -f %z "$BINARY_PATH")
        BINARY_SIZE_FORMATTED=$(format_size $BINARY_SIZE)
        
        # Get app bundle size
        APP_BUNDLE_SIZE=$(du -sk "$APP_BUNDLE_PATH" | cut -f1)
        APP_BUNDLE_SIZE_FORMATTED=$(format_size $(($APP_BUNDLE_SIZE * 1024)))
        
        # Get compilation date
        BINARY_DATE=$(stat -f %Sm -t "%Y-%m-%d %H:%M:%S" "$BINARY_PATH")
        
        # Get version - first from explicit parameter, then from env, then from Info.plist
        if [[ -n "${EXPLICIT_VERSION:-}" ]]; then
            VERSION="${EXPLICIT_VERSION}"
        elif [[ -n "${VERSION:-}" ]]; then
            VERSION="${VERSION}"
        else
            VERSION=$(defaults read "$APP_BUNDLE_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "Unknown")
        fi
        
        # Get architecture information
        ARCH=$(file "$BINARY_PATH" | grep -o "Mach-O.*" || echo "Unknown architecture")
        
        # For download link - determine the best URL to use
        if [[ -n "${EXPLICIT_ARTIFACT_URL:-}" ]]; then
            # Use explicitly provided artifact URL
            DOWNLOAD_LINK="${EXPLICIT_ARTIFACT_URL}"
        elif [[ -n "${ARTIFACT_URL:-}" ]]; then
            # Use environment variable ARTIFACT_URL if set
            DOWNLOAD_LINK="${ARTIFACT_URL}"
        elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            # Create a direct download link to the artifacts
            REPO_NAME="${GITHUB_REPOSITORY:-friendship-ai/FriendshipAI}"
            RUN_ID="${GITHUB_RUN_ID:-latest}"
            DOWNLOAD_LINK="https://github.com/${REPO_NAME}/actions/runs/${RUN_ID}/artifacts"
            
            # Check if we have a specific artifact ID
            if [[ -f "$CI_ARTIFACTS_DIR/artifact_id.txt" ]]; then
                ARTIFACT_ID=$(cat "$CI_ARTIFACTS_DIR/artifact_id.txt")
                DOWNLOAD_LINK="$DOWNLOAD_LINK/$ARTIFACT_ID"
            fi
        else
            DOWNLOAD_LINK="(Available in CI artifacts)"
        fi
        
        # Generate MD5 checksum
        CHECKSUM=$(md5 -q "$BINARY_PATH" || echo "Could not generate checksum")
        
        # Determine build type (notarized or development)
        IS_NOTARIZED=false
        NOTARIZATION_SOURCE="none"

        # First check if sign_type is explicitly provided via command line
        if [[ -n "$SIGN_TYPE" && "$SIGN_TYPE" == "notarized" ]]; then
            IS_NOTARIZED=true
            NOTARIZATION_SOURCE="explicit param"
            echo "Using explicitly provided sign_type=$SIGN_TYPE, marking as notarized"
        # Next check for environment variable
        elif [[ -n "${sign_type:-}" && "${sign_type}" == "notarized" ]]; then
            IS_NOTARIZED=true
            NOTARIZATION_SOURCE="environment"
            echo "Using environment sign_type=${sign_type}, marking as notarized"
        # Next check ZIP file name as a strong indicator
        elif [[ -f "$MAC_DIR/binary/FriendshipAI-notarized.zip" ]]; then
            IS_NOTARIZED=true
            NOTARIZATION_SOURCE="notarized zip file"
            echo "Found notarized ZIP file, marking as notarized"
        # Finally fall back to checking the app bundle
        elif [[ -f "$APP_BUNDLE_PATH/Contents/CodeResources" ]]; then
            if xcrun stapler validate "$APP_BUNDLE_PATH" &>/dev/null; then
                IS_NOTARIZED=true
                NOTARIZATION_SOURCE="stapler validate"
                echo "Manual validation with stapler succeeded, marking as notarized"
            else
                echo "Manual validation with stapler failed, marking as NOT notarized"
            fi
        fi

        # In CI build, always show the sign type for debugging
        echo "Notarization check: SIGN_TYPE='$SIGN_TYPE', sign_type='${sign_type:-}', IS_NOTARIZED=$IS_NOTARIZED, SOURCE='$NOTARIZATION_SOURCE'"

        # Additional diagnostic information when running in GitHub Actions
        if [[ -n "${GITHUB_ACTIONS:-}" || -n "${DEBUG:-}" ]]; then
            # Check for specific notarization indicators
            if [[ -f "$APP_BUNDLE_PATH/Contents/CodeResources" ]]; then
                echo "Found CodeResources file (sign indicator)"
            fi

            # Check for notarization ticket in app bundle
            if xcrun stapler validate "$APP_BUNDLE_PATH" &>/dev/null; then
                echo "Stapler validation succeeded - notarization ticket is present"
            else
                echo "Stapler validation failed - no notarization ticket found"
            fi

            # Check for notarization zip file
            if [[ -f "$MAC_DIR/binary/FriendshipAI-notarized.zip" ]]; then
                echo "Found notarized ZIP file: $MAC_DIR/binary/FriendshipAI-notarized.zip"
            else
                echo "No notarized ZIP file found at: $MAC_DIR/binary/FriendshipAI-notarized.zip"
            fi
        fi
        
        # Check if DMG exists and get its info
        # Search in multiple locations for DMG files
        SEARCH_DIRS=(
            "${MAC_DIR}/binary"
            "${REPO_ROOT}/artifacts"
            "$(dirname "${APP_BUNDLE_PATH}")"
            "${CI_ARTIFACTS_DIR}"
        )

        DMG_PATH=""
        for dir in "${SEARCH_DIRS[@]}"; do
            if [[ -d "$dir" ]]; then
                echo "Searching for DMG in $dir..."
                found_dmg=$(find "$dir" -name "*.dmg" 2>/dev/null | head -n 1)
                if [[ -n "$found_dmg" ]]; then
                    DMG_PATH="$found_dmg"
                    echo "Found DMG at: $DMG_PATH"
                    break
                fi
            fi
        done
        DMG_INFO=""
        if [[ -n "$DMG_PATH" ]]; then
            DMG_SIZE=$(stat -f %z "$DMG_PATH")
            DMG_SIZE_FORMATTED=$(format_size $DMG_SIZE)
            DMG_NAME=$(basename "$DMG_PATH")
            DMG_INFO="|  DMG File | $DMG_NAME ($DMG_SIZE_FORMATTED) |"
        fi
        
        # Get build ID and run information for troubleshooting
        BUILD_ID="${GITHUB_RUN_ID:-local}"
        BUILD_URL="https://github.com/${GITHUB_REPOSITORY:-friendship-ai/FriendshipAI}/actions/runs/${GITHUB_RUN_ID:-}"
        if [[ "$BUILD_ID" == "local" ]]; then
            BUILD_INFO="Local build (no CI information available)"
        else
            BUILD_INFO="[Build #$BUILD_ID]($BUILD_URL)"
        fi
        
        # Get timestamp for the comment update
        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

        # Find specific DMG file name and ZIP file name
        DMG_NAME=""
        ZIP_NAME=""

        if [[ -n "$DMG_PATH" ]]; then
            DMG_NAME=$(basename "$DMG_PATH")
        fi

        # Try to find ZIP file
        ZIP_PATH=""
        for dir in "${SEARCH_DIRS[@]}"; do
            if [[ -d "$dir" ]]; then
                found_zip=$(find "$dir" -name "FriendshipAI-*.zip" 2>/dev/null | head -n 1)
                if [[ -n "$found_zip" ]]; then
                    ZIP_PATH="$found_zip"
                    ZIP_NAME=$(basename "$ZIP_PATH")
                    break
                fi
            fi
        done

        # Create comment content
        COMMENT_BODY=$(cat <<EOF
## 🍎 Mac Binary Build

| Info | Details |
| --- | --- |
| Version | $VERSION |
| Build Status | ✅ Success |
| Notarization | $([ "$IS_NOTARIZED" = true ] && echo "✅ Notarized" || echo "⚠️ Development Build") |
| App Bundle Size | $APP_BUNDLE_SIZE_FORMATTED |
| Binary Size | $BINARY_SIZE_FORMATTED |
| Build | $BUILD_ID |

### Found binary at:
\`$BINARY_PATH\`

### Found app bundle at:
\`$APP_BUNDLE_PATH\`

### Found DMG at:
\`${DMG_PATH:-"Not found"}\`

### Notarization check:
SIGN_TYPE='$SIGN_TYPE', sign_type='${sign_type:-}', IS_NOTARIZED=$IS_NOTARIZED, SOURCE='$NOTARIZATION_SOURCE'

### Stapler validation:
$(xcrun stapler validate "$APP_BUNDLE_PATH" 2>&1 || echo "Stapler validation failed - no notarization ticket found")

### 📥 Download Artifacts

[Download Artifacts](${DOWNLOAD_LINK})

$([ -n "$DMG_INFO" ] && echo "✅ DMG file is available in the artifacts." || echo "")
$([ "$IS_NOTARIZED" = true ] && echo "✅ This build is notarized with Apple and can be run without security warnings." || echo "⚠️ This is a development build and may trigger security warnings on macOS.")

### Installation Instructions

1. Download and extract the artifacts from the link above
2. For DMG: Open the DMG file and drag the app to your Applications folder
3. For ZIP: Extract the ZIP and drag the app to your Applications folder
4. Right-click on the app and select "Open" to launch it the first time

🤖 *Generated by CI on $TIMESTAMP*
EOF
)

    else
        # Create error comment content
        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
        BUILD_ID="${GITHUB_RUN_ID:-local}"
        BUILD_URL="https://github.com/${GITHUB_REPOSITORY:-friendship-ai/FriendshipAI}/actions/runs/${GITHUB_RUN_ID:-}"

        if [[ "$BUILD_ID" == "local" ]]; then
            BUILD_INFO="Local build (no CI information available)"
        else
            BUILD_INFO="[Build #$BUILD_ID]($BUILD_URL)"
        fi

        # Get the URL for the workflow run logs
        if [[ -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_RUN_ID:-}" ]]; then
            LOGS_URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
        else
            LOGS_URL="#"
        fi

        # For download link - determine artifacts URL even when in error
        if [[ -n "${EXPLICIT_ARTIFACT_URL:-}" ]]; then
            DOWNLOAD_LINK="${EXPLICIT_ARTIFACT_URL}"
        elif [[ -n "${ARTIFACT_URL:-}" ]]; then
            DOWNLOAD_LINK="${ARTIFACT_URL}"
        elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            REPO_NAME="${GITHUB_REPOSITORY:-friendship-ai/FriendshipAI}"
            RUN_ID="${GITHUB_RUN_ID:-latest}"
            DOWNLOAD_LINK="https://github.com/${REPO_NAME}/actions/runs/${RUN_ID}/artifacts"
        else
            DOWNLOAD_LINK="#"
        fi

        # Create error comment
        COMMENT_BODY=$(cat <<EOF
## 🍎 Mac Binary Build

| Status | Details |
| --- | --- |
| Build Status | ❌ ${ERROR_MESSAGE:-"Build failed with an unknown error"} |
| Build | [#$BUILD_ID]($BUILD_URL) |
| Timestamp | $TIMESTAMP |

### Troubleshooting

- See the [full build logs]($LOGS_URL) for details on the failure
- Check the [build artifacts]($DOWNLOAD_LINK) for any partial builds that may be available

🤖 *Generated by CI on $TIMESTAMP*
EOF
)
    fi
    
    # If DEBUG mode is enabled, simply output the comment body and exit
    if [[ -n "${DEBUG:-}" ]]; then
        echo "$COMMENT_BODY"
        exit 0
    fi

    # If running locally, just output the comment and ask for confirmation
    if [[ -z "${GITHUB_ACTIONS:-}" ]]; then
        echo "Generated comment:"
        echo "$COMMENT_BODY"

        # Check if we should post to GitHub
        read -p "Post this comment to the PR? (y/n): " CONFIRM
        if [[ "$CONFIRM" != "y" ]]; then
            echo "Skipping PR comment posting"
            exit 0
        fi
    fi

    # When running locally, we need to explicitly post the comment
    # Note: In CI, we don't call this code path - instead, the workflow
    # uses marocchino/sticky-pull-request-comment@v2 directly with the output
    # from this script when DEBUG=true
    if [[ -z "${GITHUB_ACTIONS:-}" ]]; then
        # Get PR number and post comment
        PR_NUMBER=$(get_pr_number)

        echo "Posting comment to PR #$PR_NUMBER..."
        if [[ -n "$COMMENT_BODY" ]]; then
            # Save the comment to a temporary file for posting
            TMP_COMMENT_FILE=$(mktemp)
            echo "$COMMENT_BODY" > "$TMP_COMMENT_FILE"

            # Try to post the comment
            if ! gh pr comment "$PR_NUMBER" --body-file "$TMP_COMMENT_FILE"; then
                echo "Direct comment failed, trying with explicit repository..."
                gh pr comment "$PR_NUMBER" --repo "$GITHUB_REPOSITORY" --body-file "$TMP_COMMENT_FILE"
            fi

            # Clean up temporary file
            rm -f "$TMP_COMMENT_FILE"
        else
            echo "Error: Empty comment body"
            exit 1
        fi

        echo "✅ Successfully posted Mac binary information to PR #$PR_NUMBER"
    fi
}

# Run main function
main "$@"