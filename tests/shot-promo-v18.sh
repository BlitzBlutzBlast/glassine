#!/usr/bin/env bash
# v18 footage: the pieces of the film, each the app photographing itself on the song's grid.
# bash tests/shot-promo-v18.sh [all|<take>]
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
. tests/shot-promo-v18-lib.sh
lib() {
  rm -rf "$LIB"; mkdir -p "$LIB/Daily"
  printf '%b' ' ' > "$LIB/Draft.md"; stamp "$LIB/Draft.md" 0 0900
  printf '%b' '# Notes\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.\n' > "$LIB/Notes.md"; stamp "$LIB/Notes.md" 0 0830
  printf '%b' '# Chapter one\n\nUt enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.\n\nDuis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.\n' > "$LIB/Chapter one.md"; stamp "$LIB/Chapter one.md" 1 1900
  printf '%b' '# Ideas\n\n- Excepteur sint occaecat cupidatat non proident, \n- Sed ut perspiciatis unde omnis iste natus error sit \n- Nemo enim ipsam voluptatem quia voluptas\n' > "$LIB/Ideas.md"; stamp "$LIB/Ideas.md" 1 1400
  printf '%b' '# Field notes\n\nDuis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.\n' > "$LIB/Field notes.md"; stamp "$LIB/Field notes.md" 2 1800
  printf '%b' '# Reading\n\nNemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores.\n\nAt vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum.\n' > "$LIB/Reading.md"; stamp "$LIB/Reading.md" 2 1100
  printf '%b' '# Letter\n\nAt vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum.\n' > "$LIB/Letter.md"; stamp "$LIB/Letter.md" 3 1600
  printf '%b' '# Essay\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.\n\n## Sed ut\n\nSed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium.\n\nUt enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.\n\nExcepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\nAt vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum.\n' > "$LIB/Essay.md"; stamp "$LIB/Essay.md" 4 1700
  printf '%b' '# Journal\n\nExcepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n' > "$LIB/Journal.md"; stamp "$LIB/Journal.md" 5 0700
  local lines=('Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed' 'Ut enim ad minim veniam, quis nostrud exercitation ullamco l' 'Duis aute irure dolor in reprehenderit in voluptate velit es' 'Excepteur sint occaecat cupidatat non proident, sunt in culp' 'Sed ut perspiciatis unde omnis iste natus error sit voluptat' 'Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut ' 'At vero eos et accusamus et iusto odio dignissimos ducimus q')
  local i; for i in 0 1 2 3 4 5 6; do local d; d=$(date -v-"${i}"d '+%A, %B %-d, %Y'); printf '# %s\n\n%s\n' "$d" "${lines[$i]}" > "$LIB/Daily/$d.md"; stamp "$LIB/Daily/$d.md" "$i" 0730; done
}
DRAFT='Just you and the page.\n\nWritten in **Markdown**.\nNotes for @DATEHERE\n- [x] Call mom\n- [ ] Water the plants'; DRAFT="${DRAFT/DATEHERE/$(date '+%B %-d, %Y')}"
ORDER1="[\"Draft.md\",\"Notes.md\",\"Daily/$(date -v-0d '+%A, %B %-d, %Y').md\",\"Chapter one.md\",\"Ideas.md\",\"Daily/$(date -v-1d '+%A, %B %-d, %Y').md\",\"Field notes.md\",\"Reading.md\",\"Daily/$(date -v-2d '+%A, %B %-d, %Y').md\",\"Letter.md\",\"Daily/$(date -v-3d '+%A, %B %-d, %Y').md\",\"Essay.md\",\"Daily/$(date -v-4d '+%A, %B %-d, %Y').md\",\"Journal.md\",\"Daily/$(date -v-5d '+%A, %B %-d, %Y').md\",\"Daily/$(date -v-6d '+%A, %B %-d, %Y').md\"]"
ORDER2="[\"Draft.md\",\"Notes.md\",\"Daily/$(date -v-0d '+%A, %B %-d, %Y').md\",\"Chapter one.md\",\"Daily/$(date -v-1d '+%A, %B %-d, %Y').md\",\"Field notes.md\",\"Reading.md\",\"Daily/$(date -v-2d '+%A, %B %-d, %Y').md\",\"Letter.md\",\"Daily/$(date -v-3d '+%A, %B %-d, %Y').md\",\"Essay.md\",\"Ideas.md\",\"Daily/$(date -v-4d '+%A, %B %-d, %Y').md\",\"Journal.md\",\"Daily/$(date -v-5d '+%A, %B %-d, %Y').md\",\"Daily/$(date -v-6d '+%A, %B %-d, %Y').md\"]"
run() { case "$1" in
  glass) printf ' ' > "$LIB/Draft.md"; CARETW=0 shoot18 glass "Draft.md" 0 14.0 "" ;;
  type) printf ' ' > "$LIB/Draft.md"; shoot18 type "Draft.md" 0 21.637 '2.763:type@0:J;2.995:type@0:u;3.227:type@0:s;3.459:type@0:t;3.690:type@0: ;3.922:type@0:y;4.154:type@0:o;4.385:type@0:u;4.617:type@0: ;4.849:type@0:a;5.081:type@0:n;5.312:type@0:d;5.544:type@0: ;5.776:type@0:t;6.007:type@0:h;6.239:type@0:e;6.471:type@0: ;6.702:type@0:p;6.934:type@0:a;7.166:type@0:g;7.398:type@0:e;7.629:type@0:.;9.715:type@0:\n\n;9.946:type@0:Written in;10.178:type@0: **;10.642:type@0:Markdown;11.105:type@0:**;11.568:type@0:.;12.495:type@0:\n;12.727:type@0:Notes for;12.959:type@0: @today;13.190:type@0: ;13.422:type@0:\n- [ ] ;13.654:type@0:Call mom;14.349:type@0:\n;14.581:type@0:Water the plants;17.129:task:0;18.056:end:' ;;
  wall) printf '%b' "$DRAFT" > "$LIB/Draft.md"; EXTRA='"sortDocumentsBy":"manual","handOrder":'"$ORDER1"',' shoot18 wall "Journal.md" 999 5.0 '1.2:gallery:;3.6:wallframes:;3.7:order:' ;;
  wall2) printf '%b' "$DRAFT" > "$LIB/Draft.md"; EXTRA='"sortDocumentsBy":"manual","handOrder":'"$ORDER2"',' shoot18 wall2 "Field notes.md" 999 5.0 '1.2:gallery:;3.6:wallframes:;3.7:order:' ;;
  timelapse) printf '%b' "$DRAFT" > "$LIB/Draft.md"; shoot18 timelapse "Draft.md" 999 10.515 '2.400:daily:;2.863:walk:1;3.327:walk:1;3.790:walk:1;4.254:walk:1;4.717:walk:1;5.181:walk:1;5.644:walk:1;6.107:scope:everything;7.961:walk:-1;8.888:walk:-1' ;;
  review) HIDE=true shoot18 review "Essay.md" 999 6.807 '2.400:review:;2.863:style:editorial;3.327:style:book;3.790:style:typewriter;4.254:style:notebook;4.717:style:newspaper;5.181:style:bookDark;5.644:style:blueprint' ;;
  caret) printf ' ' > "$LIB/Field notes.md"; CARETW=6 shoot18 caret "Field notes.md" 0 10.515 '2.400:type@0:One;3.327:type@0: word;4.254:type@0: at a;5.181:type@0: time.;6.107:shape:pin;7.034:shape:comet;7.961:shape:glow;8.888:shape:bar' ;;
  looks) printf '%b' "$DRAFT" > "$LIB/Draft.md"; shoot18 looks "Draft.md" 999 6.807 '2.400:look:slate;2.863:look:deepwater;3.327:look:pine;3.790:look:plum;4.254:look:umber;4.717:look:linen;5.181:look:desktop;5.644:look:softsky' ;;
  pages) printf '%b' "$DRAFT" > "$LIB/Draft.md"; shoot18 pages "Draft.md" 999 8.198 '2.400:pages:;3.095:open:Draft.md;3.790:step:;4.717:step:;5.644:step:;6.571:commit:' ;;
  paste) printf '# Reading list\n' > "$LIB/Reading.md"; FOCUS=false TYPEWRITER=false shoot18 paste "Reading.md" 999 7.007 '1.600:warm:;2.600:pastehtml:shopping;4.404:type@0:\n\n;4.454:pastehtml:table;4.554:end:' ;;
  full) printf '%b' "$DRAFT" > "$LIB/Draft.md"; SIDEBAR=true EXTRA='"expandedFolders":["*documents"],' shoot18 full "Draft.md" 999 7.0 "" ;;
esac; }
case "${1:-all}" in
  lib) lib ;;
  all) for s in glass type wall wall2 timelapse review caret looks pages paste full; do lib; run "$s"; done ;;
  *) lib; run "$1" ;;
esac
