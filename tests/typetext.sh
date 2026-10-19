#!/usr/bin/env bash
# Text typed into the editor itself, a character at a time, from the direct
# build — for what the typing path (smart dashes, list continuation, the
# table keys) makes of it; the document is read back afterwards.
#   ./tests/typetext.sh 'line one\nline two' [delay] [pace-ms]  → dist/preview/type-text.jpg
#   SCRIPT='0.8:type@30:/table 3x4\n;1.6:key:tab' ./tests/typetext.sh x   a whole shoot script instead
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/Glassine.app"
LIB=/tmp/glassine-type-lib
T="$(getconf DARWIN_USER_TEMP_DIR)glassine-shots"
TEXT="${1:?text to type}"
DELAY="${2:-8}"
PACE="${3:-30}"
pkill -f "$APP/Contents/MacOS/Glassine" 2>/dev/null || true
rm -rf "$LIB"; mkdir -p "$LIB" "$T"
printf '# Type here\n\n' > "$LIB/Type.md"
json='{"fontSize":17,"columnWidth":680,"sidebarVisible":false,"typewriterMode":false,"focusMode":false,"themeID":"dusk","appearanceMode":"fixed","hideSyntax":false,"libraryPath":"'"$LIB"'","lastOpenedDocument":"Type.md"}'
b64=$(printf '%s' "$json" | base64 | tr -d '\n')
rm -f "$T/type-text.png" "$T/type-text.png.status" "$T/log.txt"
open -n "$APP" --args -glassine.shoot type-text.png -glassine.launchWindow 1200x860 -glassine.shootDelay "$DELAY" \
  -glassine.launchCaret 14 -glassine.launchSettings "$b64" -glassine.shootScript "${SCRIPT:-0.8:type@$PACE:$TEXT}"
w=0; until [[ -f "$T/type-text.png.status" ]]; do sleep 0.5; w=$((w+1)); (( w > 100 )) && { echo "no status"; exit 1; }; done
sleep 1.5
cat "$T/type-text.png.status"; echo
mkdir -p dist/preview
sips -z 860 1200 -s format jpeg "$T/type-text.png" --out dist/preview/type-text.jpg >/dev/null
echo "--- Type.md"; cat "$LIB/Type.md"
