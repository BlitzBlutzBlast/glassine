# v18 self-shots: the library, and one timestamped shot (frames -> 30 fps film on the script's clock).
# Look: Midnight over Soft Sky, the look the app comes with.
APP="$PWD/build/Glassine.app"
LIB=/tmp/glassine-promo-library
T="$(getconf DARWIN_USER_TEMP_DIR)glassine-shots"
OUT="$PWD/dist/promo-footage18"
mkdir -p "$OUT" "$T"
# stamp <file> <days ago> <HHMM>
stamp() { touch -t "$(date -v-"$2"d "+%Y%m%d")$3" "$1"; }
lib() {
  rm -rf "$LIB"; mkdir -p "$LIB/Daily"
  printf ' ' > "$LIB/Draft.md"; stamp "$LIB/Draft.md" 0 0900
  printf '# Letter to M.\n\nThe house is quiet and the light comes in at four.\n' > "$LIB/Letter to M.md"; stamp "$LIB/Letter to M.md" 0 0830
  printf '# Ideas\n\n- A timer that only counts the good hours\n- The sentence as a unit of attention\n' > "$LIB/Ideas.md"; stamp "$LIB/Ideas.md" 1 1900
  printf '# Reading list\n\n- The Peregrine\n- Pilgrim at Tinker Creek\n- The Rings of Saturn\n' > "$LIB/Reading list.md"; stamp "$LIB/Reading list.md" 1 1400
  printf '# Field notes\n\nThe tide was out. Herons on the flats.\n' > "$LIB/Field notes.md"; stamp "$LIB/Field notes.md" 2 1800
  printf '# Talk notes\n\n1. Open with the question\n2. Three examples, short\n3. Close with the first line\n' > "$LIB/Talk notes.md"; stamp "$LIB/Talk notes.md" 2 1100
  printf '# On Writing Slowly\n\nThe first draft is a way of finding out what you think.\n' > "$LIB/On Writing Slowly.md"; stamp "$LIB/On Writing Slowly.md" 3 1600
  printf '# Garden\n\nTomatoes in, late. The fig took.\n' > "$LIB/Garden.md"; stamp "$LIB/Garden.md" 4 1700
  printf '# Morning pages\n\nUp before the fog lifted.\n' > "$LIB/Morning pages.md"; stamp "$LIB/Morning pages.md" 5 0700
  local lines=("Fog until noon. Two pages." "A long walk, then the essay." "Rain. Read all afternoon." "Finished the second chapter." "Quiet day. Wrote early." "Market, then the garden." "Started something new.")
  local i; for i in 0 1 2 3 4 5 6; do
    local d; d=$(date -v-"${i}"d '+%A, %B %-d, %Y')
    printf '# %s\n\n%s\n' "$d" "${lines[$i]}" > "$LIB/Daily/$d.md"; stamp "$LIB/Daily/$d.md" "$i" 0730
  done
}
# shoot18 <name> <doc> <caret> <until> <script>   (env: SIDEBAR TYPEWRITER FOCUS HIDE FONT COLW LOOKTHEME BACKDROP CARETW)
shoot18() {
  local name=$1 doc=$2 caret=$3 until=$4 script=$5
  pkill -f "$APP/Contents/MacOS/Glassine" 2>/dev/null || true; sleep 0.6
  rm -f "$T/$name"-* "$T/$name.png.status"
  local json='{'"${EXTRA:-}"'"fontSize":'"${FONT:-30}"',"columnWidth":'"${COLW:-640}"',"sidebarVisible":'"${SIDEBAR:-false}"',"typewriterMode":'"${TYPEWRITER:-true}"',"focusMode":'"${FOCUS:-true}"',"themeID":"'"${THEME:-midnight}"'","appearanceMode":"fixed","showCounter":false,"hideSyntax":'"${HIDE:-true}"',"backdrop":"'"${BACKDROP:-softsky}"'","backdropDrift":true,"backdropFrost":0.2,"backdropGrain":0.085,"keepPagesOpen":true,"tourSeen":true,"looksAdopted":true,"caretBlink":"none","caretWidth":'"${CARETW:-4}"',"timelapseScope":"notes","sortDocumentsBy":"modified","libraryPath":"'"$LIB"'","lastOpenedDocument":"'"$doc"'"}'
  local b64; b64=$(printf '%s' "$json" | base64 | tr -d '\n')
  open -n "$APP" --args -glassine.shoot "$name.png" -glassine.launchWindow 1280x800 -glassine.shootDelay 1.9 \
    -glassine.launchCaret "$caret" -glassine.launchSettings "$b64" -glassine.shootFrames 99999 -glassine.shootFPS 30 \
    -glassine.shootUntil "$until" -glassine.sinkDelay 1.165 -glassine.shootScript "$script"
  local w=0; until [[ -f "$T/$name.png.status" ]]; do sleep 0.5; w=$((w+1)); (( w > 400 )) && { echo "$name: no status"; return 1; }; done
  rm -rf "$OUT/$name"; mkdir -p "$OUT/$name"; mv "$T/$name"-* "$OUT/$name/"
  python3 tests/promo-assemble.py "$OUT/$name" "$name" "$OUT/$name.mp4"
}
# still <name> <doc> <script> : one picture after the script, for framing
still() {
  local name=$1 doc=$2 script=$3 delay=${4:-4}
  pkill -f "$APP/Contents/MacOS/Glassine" 2>/dev/null || true; sleep 0.6
  rm -f "$T/$name.png" "$T/$name.png.status"
  local json='{'"${EXTRA:-}"'"fontSize":'"${FONT:-30}"',"columnWidth":'"${COLW:-640}"',"sidebarVisible":'"${SIDEBAR:-false}"',"typewriterMode":'"${TYPEWRITER:-true}"',"focusMode":'"${FOCUS:-true}"',"themeID":"'"${THEME:-midnight}"'","appearanceMode":"fixed","showCounter":false,"hideSyntax":'"${HIDE:-true}"',"backdrop":"'"${BACKDROP:-softsky}"'","backdropDrift":true,"backdropFrost":0.2,"backdropGrain":0.085,"keepPagesOpen":true,"tourSeen":true,"looksAdopted":true,"caretBlink":"none","caretWidth":'"${CARETW:-4}"',"timelapseScope":"notes","sortDocumentsBy":"modified","libraryPath":"'"$LIB"'","lastOpenedDocument":"'"$doc"'"}'
  local b64; b64=$(printf '%s' "$json" | base64 | tr -d '\n')
  open -n "$APP" --args -glassine.shoot "$name.png" -glassine.launchWindow 1280x800 -glassine.shootDelay "$delay" -glassine.launchSettings "$b64" -glassine.shootScript "$script"
  local w=0; until [[ -f "$T/$name.png.status" ]]; do sleep 0.5; w=$((w+1)); (( w > 60 )) && { echo "$name: no status"; return 1; }; done
  mkdir -p "$OUT/stills"; cp "$T/$name.png" "$OUT/stills/$name.png"; sips -Z 1280 -s format jpeg "$T/$name.png" --out "$OUT/stills/$name.jpg" >/dev/null
}
