#!/bin/zsh
# Builds signed .app bundles into build/.
#   ./scripts/build-app.sh            → build/Soundfork.app
#   ./scripts/build-app.sh TapSpike   → build/TapSpike.app
set -euo pipefail

cd "$(dirname "$0")/.."

PRODUCT="${1:-Soundfork}"
case "$PRODUCT" in
  Soundfork) NAME="Soundfork"; BUNDLE_ID="com.delightsheriff.Soundfork" ;;
  TapSpike)  NAME="TapSpike";  BUNDLE_ID="com.delightsheriff.Soundfork.TapSpike" ;;
  *) echo "unknown product: $PRODUCT" >&2; exit 1 ;;
esac

# Same identity every build, or macOS re-asks for audio-capture permission.
# Order: $SIGN_IDENTITY, the maintainer's certificate, any Apple Development certificate, ad-hoc ("-").
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  if [[ "$IDENTITIES" == *A35B7B9540258361673828381CC2BE24675A850B* ]]; then
    SIGN_IDENTITY=A35B7B9540258361673828381CC2BE24675A850B
  else
    SIGN_IDENTITY="$(awk '/Apple Development/ {print $2; exit}' <<< "$IDENTITIES")"
    SIGN_IDENTITY="${SIGN_IDENTITY:--}"
  fi
fi

swift build -c release --product "$PRODUCT"
BIN="$(swift build -c release --show-bin-path)/$PRODUCT"

APP="build/$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/$NAME"
VERSION="$(cat VERSION)"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
sed -e "s/\$(BUNDLE_ID)/$BUNDLE_ID/g" -e "s/\$(NAME)/$NAME/g" -e "s/\$(VERSION)/$VERSION/g" -e "s/\$(BUILD)/$BUILD/g" \
  Resources/Info.plist > "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Hardened runtime: blocks code injection into a process that holds the audio-capture permission.
codesign --force --options runtime --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
echo "built $APP"
