#!/usr/bin/env bash
# A paste into the editor itself, from the direct build: HTML on the clipboard
# the way a browser leaves it, pasted into a scratch document, read back.
# ./tests/pasteshot.sh → prints the document; dist/preview/syntax-paste.jpg
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/Glassine.app"
LIB=/tmp/glassine-paste-lib
T="$(getconf DARWIN_USER_TEMP_DIR)glassine-shots"
pkill -f "$APP/Contents/MacOS/Glassine" 2>/dev/null || true
rm -rf "$LIB"; mkdir -p "$LIB" "$T"
printf '# Paste here\n\n' > "$LIB/Paste.md"
swift tests/pasteboard-html.swift >/dev/null
json='{"fontSize":17,"columnWidth":680,"sidebarVisible":false,"typewriterMode":false,"focusMode":false,"themeID":"dusk","appearanceMode":"fixed","hideSyntax":false,"libraryPath":"'"$LIB"'","lastOpenedDocument":"Paste.md"}'
b64=$(printf '%s' "$json" | base64 | tr -d '\n')
rm -f "$T/syntax-paste.png" "$T/syntax-paste.png.status"
open -n "$APP" --args -glassine.shoot syntax-paste.png -glassine.launchWindow 1200x860 -glassine.shootDelay 4 \
  -glassine.launchCaret 14 -glassine.launchSettings "$b64" -glassine.shootPaste 1
w=0; until [[ -f "$T/syntax-paste.png.status" ]]; do sleep 0.5; w=$((w+1)); (( w > 60 )) && { echo "no status"; exit 1; }; done
cat "$T/syntax-paste.png.status"; echo
mkdir -p dist/preview
sips -z 860 1200 -s format jpeg "$T/syntax-paste.png" --out dist/preview/syntax-paste.jpg >/dev/null
echo "--- Paste.md"; cat "$LIB/Paste.md"
