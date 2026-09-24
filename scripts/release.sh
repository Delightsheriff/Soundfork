#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) Soundfork.app and packages it for a GitHub release:
#   build/Soundfork-<version>.dmg   drag-to-Applications disk image (what most people download)
#   build/Soundfork-<version>.zip   the same app, zipped
#   ./scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "run from a git checkout (the build number is the commit count)" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || echo "warning: uncommitted changes will be in this build" >&2

UNIVERSAL=1 ./scripts/build-app.sh Soundfork

ARCHS="$(lipo -archs build/Soundfork.app/Contents/MacOS/Soundfork)"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || { echo "expected a universal binary, got: $ARCHS" >&2; exit 1; }
codesign --verify --strict build/Soundfork.app

VERSION="$(cat VERSION)"
rm -f build/Soundfork*.zip(N) build/Soundfork*.dmg(N)

ditto -c -k --keepParent build/Soundfork.app "build/Soundfork-$VERSION.zip"

# Disk image: the app next to an Applications shortcut, so installing is one drag.
STAGE="build/dmg-staging"
rm -rf "$STAGE" && mkdir -p "$STAGE"
ditto build/Soundfork.app "$STAGE/Soundfork.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Soundfork $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "build/Soundfork-$VERSION.dmg"
rm -rf "$STAGE"
hdiutil verify -quiet "build/Soundfork-$VERSION.dmg"

echo "built build/Soundfork-$VERSION.dmg and build/Soundfork-$VERSION.zip (v$VERSION, $ARCHS)"
