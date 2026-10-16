#!/usr/bin/env bash
# Check shots of the views that changed in October 2026: the Timelapse in
# both scopes, a day's wall, the fanned pages, Settings → Look, and the
# tour's steps — from the direct build, on a temp library with a week of
# days in it. ./tests/shot-views.sh [case] → dist/preview/views-*.jpg
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/Glassine.app"
LIB=/tmp/glassine-shot-library-views
T="$(getconf DARWIN_USER_TEMP_DIR)glassine-shots"
pkill -f "$APP/Contents/MacOS/Glassine" 2>/dev/null || true
rm -rf "$LIB"; mkdir -p "$LIB/Daily" "$LIB/Essays"

# A week of daily notes, and other documents last edited on some of those days.
day() { date -v-"$1"d "+%A, %B %-d, %Y"; }
stamp() { date -v-"$1"d "+%Y%m%d%H%M"; }
for n in 0 1 2 3 5 6; do
  f="$LIB/Daily/$(day $n).md"
  printf '# %s\n\nMorning: a walk before the fog lifted, then two hours on the essay.\n\n- [ ] Call about the window\n- [x] Post the letter\n\nEvening: read, slept early.\n' "$(day $n)" > "$f"
  touch -t "$(stamp $n)" "$f"
done
printf '# On Writing Less\n\nThe shorter the sentence, the more it has to carry. A paragraph that says one thing says it twice as loud.\n\n## Cutting\n\nStart at the end. The last line was the first one you meant.\n' > "$LIB/Essays/On Writing Less.md"; touch -t "$(stamp 1)" "$LIB/Essays/On Writing Less.md"
printf '# Reading list\n\n| Book | Pages |\n| --- | ---: |\n| The Peregrine | 191 |\n| Pilgrim at Tinker Creek | 290 |\n' > "$LIB/Reading list.md"; touch -t "$(stamp 1)" "$LIB/Reading list.md"
printf '# Talk notes\n\n1. Open with the question\n2. Three examples, short\n3. Close with the first line again\n' > "$LIB/Talk notes.md"; touch -t "$(stamp 1)" "$LIB/Talk notes.md"
printf '# Garden\n\nTomatoes in, late. The fig took.\n' > "$LIB/Garden.md"; touch -t "$(stamp 1)" "$LIB/Garden.md"
printf '# Letter to M.\n\nDear M., the house is quiet and the light comes in at four.\n' > "$LIB/Letter to M.md"; touch -t "$(stamp 1)" "$LIB/Letter to M.md"
printf '# Ideas\n\n- A timer that only counts the good hours\n- The sentence as a unit of attention\n' > "$LIB/Ideas.md"; touch -t "$(stamp 3)" "$LIB/Ideas.md"
printf '# Today, untitled\n\nA page begun this morning.\n' > "$LIB/Untitled.md"
mkdir -p "$T"; : > "$T/log.txt"

shoot() {
  local name=$1; shift
  rm -f "$T/$name.png" "$T/$name.png.status"
  local json='{'"${EXTRA_JSON:-}"'"fontSize":16,"sidebarVisible":true,"typewriterMode":false,"focusMode":false,"themeID":"'"${THEME:-midnight}"'","backdrop":"'"${BACKDROP:-softsky}"'","appearanceMode":"fixed","showCounter":true,"libraryPath":"'"$LIB"'","lastOpenedDocument":"'"${DOC:-Untitled.md}"'","openPages":["Untitled.md","Essays/On Writing Less.md","Reading list.md","Talk notes.md"],"tourSeen":true}'
  local b64; b64=$(printf '%s' "$json" | base64 | tr -d '\n')
  open -n "$APP" --args -glassine.shoot "$name.png" -glassine.launchWindow 1280x840 -glassine.shootDelay "${DELAY:-4}" -glassine.launchSettings "$b64" "$@"
  local w=0; until [[ -f "$T/$name.png.status" ]]; do sleep 0.5; w=$((w+1)); (( w > 80 )) && { echo "no status"; return 1; }; done
  cat "$T/$name.png.status"; echo
  mkdir -p dist/preview
  sips -z 840 1280 -s format jpeg "$T/$name.png" --out "dist/preview/$name.jpg" >/dev/null
}
case "${1:-all}" in
  timelapse) shoot views-timelapse -glassine.launchView daily ;;
  everything) EXTRA_JSON='"timelapseScope":"everything",' shoot views-everything -glassine.launchView daily ;;
  walked) EXTRA_JSON='"timelapseScope":"everything",' DELAY=5 shoot views-walked -glassine.launchView daily -glassine.shootScript "1.5:walk:1" ;;
  day) DELAY=5 shoot views-day -glassine.shootScript "1.0:day:$(date -v-1d +%Y%m%d)" ;;
  carousel) DELAY=5 shoot views-carousel -glassine.shootScript "1.0:step:fwd;1.6:step:fwd" ;;
  pips) DELAY=5 shoot views-pips -glassine.shootScript "1.0:hover:262,829;1.3:hover:262,829" ;;
  look) shoot views-look -glassine.launchView settings:look ;;
  behind) shoot views-behind -glassine.launchView backdrops ;;
  looks) for l in softsky slate deepwater pine plum umber linen; do DELAY=4 shoot "views-look-$l" -glassine.shootScript "0.3:look:$l" -glassine.launchWindow 1120x720; done ;;
  tour) n=${2:-0}; DELAY=4.5 shoot "views-tour-$n" -glassine.launchView tour -glassine.tourStep "$n" ;;
  tourall) for n in 0 1 2 3 4 6 7 8 9 10 11; do DELAY=4.5 shoot "views-tour-$n" -glassine.launchView tour -glassine.tourStep "$n"; done ;;
  tourdone) DELAY=2.4 shoot views-tour-done -glassine.launchView tour -glassine.tourStep 2 -glassine.shootScript "0.8:gallery" ;;
  carouselclick) DELAY=4 shoot views-carousel-click -glassine.shootScript "1.0:step:fwd;1.6:click:640,400" ;;
  # The main thread held for three seconds on purpose: the watchdog should leave a report in ~/Library/Logs/Glassine and a line in log.txt.
  stall) DELAY=6 shoot views-stall -glassine.shootScript "1.0:stall:3;4.6:gallery" ;;
  # A page switched away from with unsaved text: the save and the first-line rename land off the main thread.
  switch) DELAY=6 shoot views-switch -glassine.shootScript "0.8:select:2,15;1.0:type@0:Renamed by its first line;1.8:open:Garden.md;3.4:gallery"; ls "$LIB" ;;
  all) "$0" timelapse; "$0" everything; "$0" day; "$0" carousel; "$0" look; "$0" tour 2; "$0" tour 10 ;;
esac
