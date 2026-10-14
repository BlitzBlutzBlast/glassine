#!/usr/bin/env bash
# The promo film's footage: the app performing its own features on a tiny
# library, photographed frame by frame. ./tests/shot-promo.sh [shot|all]
# Frames land in dist/promo-footage/<shot>/ and are joined into <shot>.mp4.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
APP="$PWD/build/Glassine.app"
LIB=/tmp/glassine-promo-library
T="$(getconf DARWIN_USER_TEMP_DIR)glassine-shots"
OUT="$PWD/dist/promo-footage"
mkdir -p "$OUT" "$T"
lib() {
  rm -rf "$LIB"; mkdir -p "$LIB/Daily"
  printf '' > "$LIB/Tuesday.md"
  printf '# Reading list\n' > "$LIB/Reading list.md"
  printf '# On Writing Slowly\n\nThe first draft is a way of finding out what you think.\n' > "$LIB/On Writing Slowly.md"
  printf '# Morning pages\n\nUp before the fog lifted.\n' > "$LIB/Morning pages.md"
  printf '# Field notes\n\nThe tide was out.\n' > "$LIB/Field notes.md"
  local i; for i in 0 1 2 3 4 5 6; do
    local d; d=$(date -v-"${i}"d '+%A, %B %-d, %Y')
    printf '# %s\n\nA short note.\n' "$d" > "$LIB/Daily/$d.md"
  done
}
# shoot <name> <doc> <caret> <frames> <fps> <delay> <script> [extra json] [extra args...]
shoot() {
  local name=$1 doc=$2 caret=$3 frames=$4 fps=$5 delay=$6 script=$7 extra=${8:-}; shift 8 || shift $#
  pkill -f "$APP/Contents/MacOS/Glassine" 2>/dev/null || true; sleep 0.5
  rm -f "$T/$name"*.png "$T/$name.png.status"
  local json='{'"$extra"'"fontSize":18,"columnWidth":660,"sidebarVisible":'"${SIDEBAR:-true}"',"typewriterMode":'"${TYPEWRITER:-true}"',"focusMode":'"${FOCUS:-true}"',"themeID":"'"${THEME:-dusk}"'","appearanceMode":"fixed","showCounter":true,"hideSyntax":false,"backdrop":"'"${BACKDROP:-aurora}"'","backdropDrift":true,"backdropFrost":0.3,"keepPagesOpen":true,"tourSeen":true,"caretBlink":"none","libraryPath":"'"$LIB"'","lastOpenedDocument":"'"$doc"'"}'
  local b64; b64=$(printf '%s' "$json" | base64 | tr -d '\n')
  open -n "$APP" --args -glassine.shoot "$name.png" -glassine.launchWindow 1440x880 -glassine.shootDelay "$delay" -glassine.launchCaret "$caret" -glassine.launchSettings "$b64" -glassine.shootFrames "$frames" -glassine.shootFPS "$fps" -glassine.shootScript "$script" "$@"
  local w=0; until [[ -f "$T/$name.png.status" ]]; do sleep 0.5; w=$((w+1)); (( w > 240 )) && { echo "$name: no status"; return 1; }; done
  echo "$name: $(cat "$T/$name.png.status") $(ls "$T/$name"-*.png 2>/dev/null | wc -l) frames"
  rm -rf "$OUT/$name"; mkdir -p "$OUT/$name"; mv "$T/$name"-*.png "$OUT/$name/"
  ffmpeg -y -loglevel error -framerate "$fps" -i "$OUT/$name/$name-%03d.png" -c:v libx264 -crf 14 -pix_fmt yuv420p -vf "scale=2880:1760" "$OUT/$name.mp4"
  echo "  -> $OUT/$name.mp4"
}
run() { case "$1" in
  # Every clip starts at the shoot delay (2.0 s); an action at script time t is at t-2.0 in the clip.
  # 1 — song 0–11.8: a caret alone, the sentence typed at 2.84, then the quiet (tricks allowed)
  write1) printf '' > "$LIB/Tuesday.md"; SIDEBAR=false shoot write1 Tuesday.md 0 290 24 2.0 "4.84:type:A quiet place to write." ;;
  # 2 — song 11.84–21.6: the sidebar's window; Focus 13.0 → typing 13.46; Tasks 16.53 → check 16.98; bold line 17.25; Just the words 18.89 → ⌃⌘M 19.34
  write) printf 'A quiet place to write.' > "$LIB/Tuesday.md"; shoot write Tuesday.md 999 236 24 2.0 "3.62:type:\nStarted @today\n- [ ] Call mom\nWater the plants;7.14:task:0;7.41:type:\n\nFinish the **draft** tonight.;9.3:select:0;9.5:syntax" ;;
  # 3 — song 21.54–30.6: Review 22.04, styles 22.42/22.71/23.30/23.59, beside 24.38, Onward. 25.07, Library 26.68, Timelapse 29.03
  build) shoot build Tuesday.md 999 220 24 2.0 "2.5:review;2.88:style:github;3.17:style:book;3.76:style:mono;4.05:style:bookDark;4.84:beside;5.4:select:999;5.53:type:\nOnward.;7.14:gallery;9.49:daily" ;;
  # 4 — song 30.63: Paste. → ⌘V at 31.13
  paste) swift tests/pasteboard-promo.swift; shoot paste "Reading list.md" 999 60 24 2.0 "2.5:paste" ;;
  # 5 — song 32.97: Tables. → typed fast from 33.47, Tab Tab
  table) printf '# Reading list\n' > "$LIB/Reading list.md"; shoot table "Reading list.md" 999 60 24 2.0 "2.5:type@28:\n| Book | Pages |\n| --- | --- |\n| The Peregrine | 191 |;4.0:key:tab;4.3:key:tab" ;;
  # 6 — song 35.32: Pages. → ⌥⇥ at 35.82, steps 36.42 / 36.82, let go 37.32
  pages) shoot pages "Reading list.md" 999 60 24 2.0 "2.5:pages;3.1:step;3.5:step;4.0:commit" ;;
  # 7 — song 37.66: Yours. → nine themes from 38.16, one every 0.465
  themes) shoot themes "Reading list.md" 999 115 24 2.0 "2.5:theme:ocean;2.965:theme:lavender;3.43:theme:graphite;3.895:theme:sepia;4.36:theme:midnight;4.825:theme:moss;5.29:theme:frost;5.755:theme:paper;6.22:theme:dusk" ;;
  # 8 — song 42.35: Caret. → eight shapes from 42.85, one every 0.23
  carets) SIDEBAR=false shoot carets Tuesday.md 999 60 24 2.0 "2.5:shape:pin;2.73:shape:serif;2.96:shape:wedge;3.19:shape:ghost;3.42:shape:comet;3.65:shape:glow;3.88:shape:hollow;4.11:shape:bar" ;;
  # 9 — song 44.68: Behind the glass. → four backdrops from 45.18, one every 0.5, a touch of frost
  backdrops) shoot backdrops Tuesday.md 999 60 24 2.0 "2.5:backdrop:nebula;3.0:backdrop:ember;3.5:backdrop:borealis;4.0:backdrop:rose;4.4:frost:0.8" ;;
  # 10 — song 47.02: Search. → ⌘F at 47.52, the word typed
  search) BACKDROP=aurora shoot search "Reading list.md" 999 60 24 2.0 "2.5:search:peregrine" ;;
  # 11 — song 58.7–65.6: the quiet, the caret's tricks
  idle) shoot idle Tuesday.md 999 170 24 2.0 "20:esc" "" -glassine.trickAfter 1.5 ;;
esac; }
case "${1:-all}" in
  lib) lib ;;
  all) lib; for s in write1 write paste table pages themes carets backdrops search build idle; do run "$s"; done ;;
  *) run "$1" ;;
esac
