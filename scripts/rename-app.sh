#!/bin/bash
# Rename the app identity across the repo: directories, target names,
# bundle id, Keychain service, and every source/doc reference.
# Usage: scripts/rename-app.sh OldName NewName
# Notes: changing the name changes the bundle id, so macOS permission
# grants (microphone, accessibility, screen) reset, and Keychain items
# stored under the old service are not migrated.
set -euo pipefail

OLD="${1:?usage: rename-app.sh OldName NewName}"
NEW="${2:?usage: rename-app.sh OldName NewName}"
cd "$(dirname "$0")/.."

# 1. Directory and file renames (git mv keeps history).
[ -d "$OLD" ] && git mv "$OLD" "$NEW"
[ -d "${OLD}Tests" ] && git mv "${OLD}Tests" "${NEW}Tests"
[ -d "${OLD}UITests" ] && git mv "${OLD}UITests" "${NEW}UITests"
[ -f "$NEW/Resources/$OLD.entitlements" ] \
  && git mv "$NEW/Resources/$OLD.entitlements" "$NEW/Resources/$NEW.entitlements"

# 2. Content rename in tracked text files (skip LICENSE: pure GPL text).
git ls-files | grep -vE '^LICENSE$' | while read -r f; do
  [ -f "$f" ] || continue
  case "$f" in
    *.png|*.icns|*.car) continue ;;
  esac
  if LC_ALL=C grep -q "$OLD" "$f" 2>/dev/null; then
    sed -i '' "s/$OLD/$NEW/g" "$f"
  fi
done

echo "Renamed $OLD -> $NEW. Now run: xcodegen generate && build + test."
