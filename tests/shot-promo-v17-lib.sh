# v17 self-shots: the tiny library, and one timestamped shot (frames -> 30 fps film on the script's clock).
APP="$PWD/build/Glassine.app"
LIB=/tmp/glassine-promo-library
T="$(getconf DARWIN_USER_TEMP_DIR)glassine-shots"
OUT="$PWD/dist/promo-footage17"
mkdir -p "$OUT" "$T"
lib() {
  rm -rf "$LIB"; mkdir -p "$LIB/Daily"
  printf ' ' > "$LIB/Tuesday.md"
  printf '# Reading list\n' > "$LIB/Reading list.md"
  printf '# On Writing Slowly\n\nThe first draft is a way of finding out what you think.\n' > "$LIB/On Writing Slowly.md"
  printf '# Morning pages\n\nUp before the fog lifted.\n' > "$LIB/Morning pages.md"
  printf '# Field notes\n\nThe tide was out.\n' > "$LIB/Field notes.md"
  local i; for i in 0 1 2 3 4 5 6; do
    local d; d=$(date -v-"${i}"d '+%A, %B %-d, %Y')
    printf '# %s\n\nA short note.\n' "$d" > "$LIB/Daily/$d.md"
  done
}
# shoot17 <name> <doc> <caret> <until> <script>
shoot17() {
  local name=$1 doc=$2 caret=$3 until=$4 script=$5
  pkill -f "$APP/Contents/MacOS/Glassine" 2>/dev/null || true; sleep 0.6
  rm -f "$T/$name"-* "$T/$name.png.status"
  local json='{"fontSize":24,"columnWidth":600,"sidebarVisible":'"${SIDEBAR:-false}"',"typewriterMode":'"${TYPEWRITER:-true}"',"focusMode":'"${FOCUS:-true}"',"themeID":"'"${THEME:-dusk}"'","appearanceMode":"fixed","showCounter":false,"hideSyntax":'"${HIDE:-false}"',"backdrop":"'"${BACKDROP:-aurora}"'","backdropDrift":true,"backdropFrost":'"${FROST:-0.3}"',"keepPagesOpen":true,"tourSeen":true,"caretBlink":"none","caretWidth":'"${CARETW:-4}"',"libraryPath":"'"$LIB"'","lastOpenedDocument":"'"$doc"'"}'
  local b64; b64=$(printf '%s' "$json" | base64 | tr -d '\n')
  open -n "$APP" --args -glassine.shoot "$name.png" -glassine.launchWindow 1280x800 -glassine.shootDelay 1.9 \
    -glassine.launchCaret "$caret" -glassine.launchSettings "$b64" -glassine.shootFrames 99999 -glassine.shootFPS 30 \
    -glassine.shootUntil "$until" -glassine.sinkDelay 1.165 -glassine.shootScript "$script"
  local w=0; until [[ -f "$T/$name.png.status" ]]; do sleep 0.5; w=$((w+1)); (( w > 240 )) && { echo "$name: no status"; return 1; }; done
  rm -rf "$OUT/$name"; mkdir -p "$OUT/$name"; mv "$T/$name"-* "$OUT/$name/"
  python3 tests/promo-assemble.py "$OUT/$name" "$name" "$OUT/$name.mp4"
}
