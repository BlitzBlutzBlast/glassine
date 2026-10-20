#!/usr/bin/env bash
# A paste of plain text into the editor itself, from the direct build: the
# clipboard holds only a string (what Claude's Copy button, a terminal or a
# code editor leave), pasted into a scratch document and read back after the
# app has had time to second-guess it.
#   ./tests/pastetext.sh file.md [delay]   → prints the document; dist/preview/paste-text.jpg
#   THEN=120,0 puts the caret somewhere a second after the paste; HIDE, FONT, COLUMN, THEME, WINDOW, PAGE, CARET as named
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/Glassine.app"
LIB=/tmp/glassine-paste-lib
T="$(getconf DARWIN_USER_TEMP_DIR)glassine-shots"
SRC="${1:?a file to paste}"
DELAY="${2:-6}"
pkill -f "$APP/Contents/MacOS/Glassine" 2>/dev/null || true
rm -rf "$LIB"; mkdir -p "$LIB" "$T"
printf '%b' "${PAGE:-# Paste here\n\n}" > "$LIB/Paste.md"
if [[ "$SRC" == *.html ]]; then swift tests/pasteboard-file.swift "$SRC" "${SRC%.html}.txt" >/dev/null; else pbcopy < "$SRC"; fi
json='{"fontSize":'"${FONT:-17}"',"columnWidth":'"${COLUMN:-680}"',"sidebarVisible":false,"typewriterMode":false,"focusMode":false,"themeID":"'"${THEME:-dusk}"'","appearanceMode":"fixed","hideSyntax":'"${HIDE:-false}"',"libraryPath":"'"$LIB"'","lastOpenedDocument":"Paste.md"}'
b64=$(printf '%s' "$json" | base64 | tr -d '\n')
rm -f "$T/paste-text.png" "$T/paste-text.png.status" "$T/log.txt"
open -n "$APP" --args -glassine.shoot paste-text.png -glassine.launchWindow "${WINDOW:-1200x860}" -glassine.shootDelay "$DELAY" \
  -glassine.launchCaret "${CARET:-14}" -glassine.launchSettings "$b64" -glassine.shootPaste 1 ${THEN:+-glassine.shootSelectThen "$THEN"}
w=0; until [[ -f "$T/paste-text.png.status" ]]; do sleep 0.5; w=$((w+1)); (( w > 80 )) && { echo "no status"; exit 1; }; done
sleep 1.5
cat "$T/paste-text.png.status"; echo
mkdir -p dist/preview
sips -z 860 1200 -s format jpeg "$T/paste-text.png" --out dist/preview/paste-text.jpg >/dev/null
echo "--- Paste.md"; cat "$LIB/Paste.md"
