#!/bin/bash
# scripts/release.sh — One-shot release: bump VERSION, update CHANGELOG,
# build universal .app + .dmg, tag, push, and create a GitHub release.
#
# Usage: ./scripts/release.sh <new-version>          # e.g. 0.2.0
#        ./scripts/release.sh <new-version> --dry    # build artifacts but skip tag/push
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <version> [--dry]"
    exit 1
fi
VERSION="$1"
DRY=""
[ "$2" = "--dry" ] && DRY=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Sanity: clean working tree (otherwise version-bump commit will mix in unrelated edits)
if [ -z "$DRY" ] && [ -n "$(git status --porcelain)" ]; then
    echo "Working tree is dirty. Commit or stash before releasing."
    git status --short
    exit 1
fi

# Sanity: tag must not exist
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo "Tag v$VERSION already exists."
    exit 1
fi

# Update VERSION file
echo "$VERSION" > VERSION

# Generate changelog entry from commits since last tag
LAST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
DATE="$(date +%Y-%m-%d)"
ENTRY="$(mktemp)"
{
    echo "## [$VERSION] - $DATE"
    echo
    if [ -n "$LAST_TAG" ]; then
        git log --pretty=format:"- %s" "$LAST_TAG..HEAD" | grep -v '^- release:' || true
    else
        git log --pretty=format:"- %s"
    fi
    echo
    echo
} > "$ENTRY"

# Prepend the new entry directly under the [Unreleased] header
TMP_CHANGELOG="$(mktemp)"
awk -v entry_file="$ENTRY" '
    BEGIN { inserted = 0 }
    /^## \[Unreleased\]/ && !inserted {
        print
        print ""
        while ((getline line < entry_file) > 0) print line
        close(entry_file)
        inserted = 1
        next
    }
    { print }
' CHANGELOG.md > "$TMP_CHANGELOG"
mv "$TMP_CHANGELOG" CHANGELOG.md
rm -f "$ENTRY"

# Build the .dmg with the new version
"$SCRIPT_DIR/make-app.sh" universal
"$SCRIPT_DIR/make-dmg.sh" "$VERSION"

if [ -n "$DRY" ]; then
    echo
    echo "Dry run: artifacts ready at dist/Gesture-$VERSION.dmg, but no tag/push/release."
    echo "VERSION and CHANGELOG.md were updated locally — review and revert if you want to retry."
    exit 0
fi

# Tag, push, release
git add VERSION CHANGELOG.md
git commit -m "release: v$VERSION"
git tag -a "v$VERSION" -m "v$VERSION"
git push origin HEAD
git push origin "v$VERSION"

# Release notes — extract just our newly-added section
NOTES="$(mktemp)"
awk -v ver="$VERSION" '
    $0 ~ "^## \\[" ver "\\]" { found = 1; print; next }
    found && /^## \[/ { exit }
    found { print }
' CHANGELOG.md > "$NOTES"

gh release create "v$VERSION" "dist/Gesture-$VERSION.dmg" \
    --title "v$VERSION" \
    --notes-file "$NOTES"

rm -f "$NOTES"
echo
echo "Release v$VERSION published."
