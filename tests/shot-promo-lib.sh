# shared by the promo shoots: the tiny library, and one shot (frames -> mp4)
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
