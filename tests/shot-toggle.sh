#!/usr/bin/env bash
# The sidebar shown and hidden in quick succession, on a temp library with one
# long document and the caret in the middle of it: the column must come back
# centred, wrapped to its width, with the caret's line where it was.
#   tests/shot-toggle.sh [count] [gap] [window]   → dist/preview/toggle.jpg
#   TYPEWRITER=false FOCUS=false tests/shot-toggle.sh 5 0.5 880x700
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/Glassine.app"
LIB=/tmp/glassine-shot-library-toggle
T="$(getconf DARWIN_USER_TEMP_DIR)glassine-shots"
pkill -f "$APP/Contents/MacOS/Glassine" 2>/dev/null || true
rm -rf "$LIB"; mkdir -p "$LIB"
python3 - "$LIB" <<'PY'
import sys, os, random
random.seed(7)
words = ("the quiet parts of the day are the ones worth writing down and the page is patient about it " * 40).split()
paras = [" ".join(random.choices(words, k=random.choice([30, 60, 90, 140]))) for _ in range(60)]
open(os.path.join(sys.argv[1], "Long.md"), "w").write("# Long\n\n" + "\n\n".join(paras) + "\n")
PY
mkdir -p "$T"; : > "$T/log.txt"; rm -f "$T/toggle.png" "$T/toggle.png.status"
json='{"fontSize":16,"columnWidth":660,"sidebarVisible":true,"sidebarWidth":250,"typewriterMode":'"${TYPEWRITER:-true}"',"focusMode":'"${FOCUS:-true}"',"themeID":"dusk","appearanceMode":"fixed","libraryPath":"'"$LIB"'","lastOpenedDocument":"Long.md"}'
b64=$(printf '%s' "$json" | base64 | tr -d '\n')
open -n "$APP" --args -glassine.shoot toggle.png -glassine.launchWindow "${3:-1200x860}" -glassine.shootDelay 5 -glassine.launchSettings "$b64" -glassine.shootToggle "${1:-6},${2:-0.12}"
w=0; until [[ -f "$T/toggle.png.status" ]]; do sleep 0.5; w=$((w+1)); (( w > 60 )) && { echo "no status"; exit 1; }; done
cat "$T/toggle.png.status"; echo
mkdir -p dist/preview
sips -Z 1200 -s format jpeg -s formatOptions 85 "$T/toggle.png" --out dist/preview/toggle.jpg >/dev/null
