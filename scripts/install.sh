#!/bin/zsh
# Builds Soundfork, installs it to /Applications and (re)launches it.
#   ./scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh Soundfork

# Quit any running copy (including the pre-rename AudioRouter) so its routes are torn down cleanly.
for app in Soundfork AudioRouter; do
  if pgrep -xq "$app"; then
    osascript -e "quit app \"$app\"" >/dev/null 2>&1 || pkill -x "$app" || true
  fi
done
while pgrep -xq Soundfork || pgrep -xq AudioRouter; do sleep 0.2; done

rm -rf /Applications/Soundfork.app
ditto build/Soundfork.app /Applications/Soundfork.app
echo "installed /Applications/Soundfork.app"

open /Applications/Soundfork.app
