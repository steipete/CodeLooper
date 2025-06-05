#!/bin/bash

# CodeLooper Version Management Script
# Provides automated version bumping with semantic versioning support
# Adapted from VibeMeter's sophisticated version management approach

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/Project.swift"

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Version Management Options:
  --major               Bump major version (e.g., 1.2.3 → 2.0.0)
  --minor               Bump minor version (e.g., 1.2.3 → 1.3.0)
  --patch               Bump patch version (e.g., 1.2.3 → 1.2.4)
  --prerelease TYPE     Create pre-release version (alpha|beta|rc)
  --build               Bump build number only
  --set VERSION         Set specific version
  --current             Show current version information
  --help                Show this help message

Pre-release Examples:
  $0 --prerelease beta        # 1.2.3 → 1.2.3-beta.1
  $0 --prerelease alpha       # 1.2.3 → 1.2.3-alpha.1
  $0 --prerelease rc          # 1.2.3 → 1.2.3-rc.1

Examples:
  $0 --current                # Show current version
  $0 --patch                  # Bump patch version
  $0 --minor                  # Bump minor version
  $0 --major                  # Bump major version
  $0 --build                  # Bump build number only
  $0 --set "2.0.0"           # Set specific version
  $0 --prerelease beta        # Create beta pre-release
EOF
}

# Extract current version from Project.swift
get_current_version() {
    if [[ ! -f "$PROJECT_FILE" ]]; then
        print_error "Project.swift not found at $PROJECT_FILE"
        exit 1
    fi
    
    local marketing_version
    local build_version
    
    # Extract marketing version
    marketing_version=$(grep "MARKETING_VERSION" "$PROJECT_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    if [[ -z "$marketing_version" ]]; then
        print_error "Could not extract MARKETING_VERSION from Project.swift"
        exit 1
    fi
    
    # Extract build version
    build_version=$(grep "CURRENT_PROJECT_VERSION" "$PROJECT_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    if [[ -z "$build_version" ]]; then
        print_error "Could not extract CURRENT_PROJECT_VERSION from Project.swift"
        exit 1
    fi
    
    echo "$marketing_version|$build_version"
}

# Parse semantic version into components
parse_version() {
    local version="$1"
    
    # Remove any pre-release suffix for parsing
    local base_version="${version%%-*}"
    local prerelease_suffix=""
    
    if [[ "$version" == *"-"* ]]; then
        prerelease_suffix="${version#*-}"
    fi
    
    # Parse major.minor.patch
    if [[ "$base_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        local major="${BASH_REMATCH[1]}"
        local minor="${BASH_REMATCH[2]}"
        local patch="${BASH_REMATCH[3]}"
        echo "$major|$minor|$patch|$prerelease_suffix"
    else
        print_error "Invalid version format: $version (expected: major.minor.patch)"
        exit 1
    fi
}

# Create new version based on bump type
calculate_new_version() {
    local current_version="$1"
    local bump_type="$2"
    local prerelease_type="$3"
    local set_version="$4"
    
    if [[ -n "$set_version" ]]; then
        echo "$set_version"
        return
    fi
    
    local version_parts
    version_parts=$(parse_version "$current_version")
    
    IFS='|' read -r major minor patch prerelease <<< "$version_parts"
    
    case "$bump_type" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            prerelease=""
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            prerelease=""
            ;;
        "patch")
            patch=$((patch + 1))
            prerelease=""
            ;;
        "prerelease")
            # If already a pre-release of the same type, increment number
            if [[ "$prerelease" == "$prerelease_type"* ]]; then
                local current_num
                current_num=$(echo "$prerelease" | sed "s/$prerelease_type\.//" | sed 's/[^0-9].*//')
                if [[ -n "$current_num" && "$current_num" =~ ^[0-9]+$ ]]; then
                    local new_num=$((current_num + 1))
                    prerelease="$prerelease_type.$new_num"
                else
                    prerelease="$prerelease_type.1"
                fi
            else
                # New pre-release type
                prerelease="$prerelease_type.1"
            fi
            ;;
        *)
            print_error "Invalid bump type: $bump_type"
            exit 1
            ;;
    esac
    
    local new_version="$major.$minor.$patch"
    if [[ -n "$prerelease" ]]; then
        new_version="$new_version-$prerelease"
    fi
    
    echo "$new_version"
}

# Update version in Project.swift
update_project_file() {
    local new_marketing_version="$1"
    local new_build_version="$2"
    
    # Create backup
    cp "$PROJECT_FILE" "$PROJECT_FILE.bak"
    print_info "Created backup: $PROJECT_FILE.bak"
    
    # Update marketing version
    if command -v gsed &> /dev/null; then
        gsed -i "s/\"MARKETING_VERSION\": \"[^\"]*\"/\"MARKETING_VERSION\": \"$new_marketing_version\"/" "$PROJECT_FILE"
    else
        sed -i '' "s/\"MARKETING_VERSION\": \"[^\"]*\"/\"MARKETING_VERSION\": \"$new_marketing_version\"/" "$PROJECT_FILE"
    fi
    
    # Update build version
    if command -v gsed &> /dev/null; then
        gsed -i "s/\"CURRENT_PROJECT_VERSION\": \"[^\"]*\"/\"CURRENT_PROJECT_VERSION\": \"$new_build_version\"/" "$PROJECT_FILE"
    else
        sed -i '' "s/\"CURRENT_PROJECT_VERSION\": \"[^\"]*\"/\"CURRENT_PROJECT_VERSION\": \"$new_build_version\"/" "$PROJECT_FILE"
    fi
    
    print_success "Updated $PROJECT_FILE"
}

# Show current version information
show_current_version() {
    local version_info
    version_info=$(get_current_version)
    
    IFS='|' read -r marketing_version build_version <<< "$version_info"
    
    echo -e "${BLUE}Current Version Information:${NC}"
    echo "  Marketing Version: $marketing_version"
    echo "  Build Version: $build_version"
    echo "  Project File: $PROJECT_FILE"
}

# Confirm version change
confirm_version_change() {
    local current_version="$1"
    local new_version="$2"
    local current_build="$3"
    local new_build="$4"
    
    echo
    echo -e "${YELLOW}Version Change Summary:${NC}"
    echo "  Marketing Version: $current_version → $new_version"
    echo "  Build Version: $current_build → $new_build"
    echo
    
    read -p "Do you want to proceed with this version change? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Version change cancelled"
        exit 0
    fi
}

# Main function
main() {
    local bump_type=""
    local prerelease_type=""
    local set_version=""
    local build_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --major)
                bump_type="major"
                shift
                ;;
            --minor)
                bump_type="minor"
                shift
                ;;
            --patch)
                bump_type="patch"
                shift
                ;;
            --prerelease)
                bump_type="prerelease"
                prerelease_type="$2"
                if [[ -z "$prerelease_type" ]] || [[ "$prerelease_type" == --* ]]; then
                    print_error "Pre-release type required (alpha|beta|rc)"
                    exit 1
                fi
                shift 2
                ;;
            --build)
                build_only=true
                shift
                ;;
            --set)
                set_version="$2"
                if [[ -z "$set_version" ]] || [[ "$set_version" == --* ]]; then
                    print_error "Version string required for --set"
                    exit 1
                fi
                shift 2
                ;;
            --current)
                show_current_version
                exit 0
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate arguments
    if [[ -z "$bump_type" ]] && [[ -z "$set_version" ]] && [[ "$build_only" == false ]]; then
        print_error "No version operation specified"
        usage
        exit 1
    fi
    
    # Validate pre-release type
    if [[ "$bump_type" == "prerelease" ]]; then
        case "$prerelease_type" in
            alpha|beta|rc)
                ;;
            *)
                print_error "Invalid pre-release type: $prerelease_type (must be alpha, beta, or rc)"
                exit 1
                ;;
        esac
    fi
    
    # Get current version
    local version_info
    version_info=$(get_current_version)
    IFS='|' read -r current_marketing_version current_build_version <<< "$version_info"
    
    # Calculate new versions
    local new_marketing_version="$current_marketing_version"
    local new_build_version
    
    if [[ "$build_only" == true ]]; then
        new_build_version=$((current_build_version + 1))
    else
        new_marketing_version=$(calculate_new_version "$current_marketing_version" "$bump_type" "$prerelease_type" "$set_version")
        new_build_version=$((current_build_version + 1))
    fi
    
    # Show changes and confirm
    confirm_version_change "$current_marketing_version" "$new_marketing_version" "$current_build_version" "$new_build_version"
    
    # Update the project file
    update_project_file "$new_marketing_version" "$new_build_version"
    
    print_success "Version updated successfully!"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Review the changes: git diff Project.swift"
    echo "2. Regenerate Xcode project: ./scripts/generate-xcproj.sh"
    echo "3. Commit the changes: git add Project.swift && git commit -m 'Bump version to $new_marketing_version ($new_build_version)'"
    echo "4. Create a release: ./scripts/release.sh stable"
    
    if [[ "$new_marketing_version" == *"-"* ]]; then
        local prerelease_type_extracted
        prerelease_type_extracted=$(echo "$new_marketing_version" | sed 's/.*-\([^.]*\).*/\1/')
        local prerelease_number
        prerelease_number=$(echo "$new_marketing_version" | sed 's/.*\.\([0-9]*\)$/\1/')
        echo "   (For pre-release: ./scripts/release.sh $prerelease_type_extracted $prerelease_number)"
    fi
}

# Run main function with all arguments
main "$@"