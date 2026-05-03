#!/usr/bin/env bash
# Bump the homebrew-tote tap to a new Tote release.
#
# Usage: ./scripts/bump-tap.sh <version>
# Example: ./scripts/bump-tap.sh 0.1.0
#
# Assumes:
#  - The release zip lives at build/Tote-<version>.zip
#  - The tap repo is checked out at ~/Development/homebrew-tote
#  - You can push to it
#
# What it does:
#  1. Computes sha256 of build/Tote-<version>.zip
#  2. Rewrites Casks/tote.rb in the tap with the new version + sha256
#  3. Commits and pushes the tap repo

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>" >&2
    echo "Example: $0 0.1.0" >&2
    exit 1
fi

TOTE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAP_ROOT="${TOTE_TAP_ROOT:-$HOME/Development/homebrew-tote}"
ZIP_PATH="$TOTE_ROOT/build/Tote-$VERSION.zip"
CASK_PATH="$TAP_ROOT/Casks/tote.rb"

[[ -f "$ZIP_PATH" ]] || { echo "Error: $ZIP_PATH not found. Build the release first." >&2; exit 1; }
[[ -d "$TAP_ROOT" ]] || { echo "Error: tap repo not found at $TAP_ROOT" >&2; exit 1; }
[[ -f "$CASK_PATH" ]] || { echo "Error: $CASK_PATH not found" >&2; exit 1; }

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
echo "Version: $VERSION"
echo "SHA256:  $SHA256"

# Rewrite version + sha256 lines. Other content of the cask is preserved.
# BSD sed (macOS) — needs '' as the in-place backup arg.
sed -i '' \
    -e "s|^  version \".*\"|  version \"$VERSION\"|" \
    -e "s|^  sha256 \".*\"|  sha256 \"$SHA256\"|" \
    "$CASK_PATH"

cd "$TAP_ROOT"
if git diff --quiet Casks/tote.rb; then
    echo "No changes — cask already at $VERSION."
    exit 0
fi

git add Casks/tote.rb
git commit -m "Bump tote to $VERSION"
git push

echo "Tap bumped to $VERSION."
