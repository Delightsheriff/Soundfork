#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) Soundfork.app and zips it for a GitHub release.
#   ./scripts/release.sh   → build/Soundfork.zip (and build/Soundfork-<version>.zip)
set -euo pipefail
cd "$(dirname "$0")/.."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "run from a git checkout (the build number is the commit count)" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || echo "warning: uncommitted changes will be in this build" >&2

UNIVERSAL=1 ./scripts/build-app.sh Soundfork

ARCHS="$(lipo -archs build/Soundfork.app/Contents/MacOS/Soundfork)"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || { echo "expected a universal binary, got: $ARCHS" >&2; exit 1; }
codesign --verify --strict build/Soundfork.app

VERSION="$(cat VERSION)"
rm -f build/Soundfork.zip "build/Soundfork-$VERSION.zip"
ditto -c -k --keepParent build/Soundfork.app build/Soundfork.zip
cp build/Soundfork.zip "build/Soundfork-$VERSION.zip"
echo "built build/Soundfork.zip (v$VERSION, $ARCHS)"
