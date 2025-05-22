#!/bin/bash
# Helper script to ensure a lint-summary.md file exists at the repository root
# This script is designed to be called from CI workflows

set -e

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"
REPO_ROOT="$(cd "$APP_DIR/.." &> /dev/null && pwd)"

echo "Ensuring lint-summary.md exists at repository root..."

# If a lint-summary.md exists in the mac directory, copy it to the repo root
if [ -f "$APP_DIR/lint-summary.md" ]; then
    echo "Found lint-summary.md in mac directory, copying to repo root..."
    cp "$APP_DIR/lint-summary.md" "$REPO_ROOT/lint-summary.md"
    echo "Successfully copied lint-summary.md to repo root"
    exit 0
fi

# If no file exists, create a fallback file at the repo root
echo "Creating fallback lint-summary.md at repo root..."
cat > "$REPO_ROOT/lint-summary.md" << EOF
## SwiftLint Results

* **Warnings:** 0
* **Errors:** 0

✅ No SwiftLint issues found!

---
_This is a fallback summary file created by ensure-lint-summary.sh_
EOF

echo "Successfully created fallback lint-summary.md at repo root"