#!/usr/bin/env bash
# v16 footage: every action on the song's beat grid (generated). bash tests/shot-promo-v16.sh [all|shot]
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
APP="$PWD/build/Glassine.app"
LIB=/tmp/glassine-promo-library
T="$(getconf DARWIN_USER_TEMP_DIR)glassine-shots"
OUT="$PWD/dist/promo-footage16"
mkdir -p "$OUT" "$T"
. tests/shot-promo-lib.sh
run() { case "$1" in
  write1) printf '' > "$LIB/Tuesday.md"; SIDEBAR=false shoot write1 "Tuesday.md" 0 294 24 2.0 "4.368:type@100:A quiet place to write." "" ;;
  write) printf 'A quiet place to write.' > "$LIB/Tuesday.md"; shoot write "Tuesday.md" 999 293 24 2.0 "4.945:type@50:\nStarted @today\n- [ ] Call mom\nWater the plants\n\nFinish the **draft** tonight.;9.647:task:0;11.992:select:0;12.042:syntax" "" ;;
  paste) swift tests/pasteboard-promo.swift; shoot paste "Reading list.md" 999 66 24 2.0 "2.569:paste" "" ;;
  table) printf '# Reading list\n' > "$LIB/Reading list.md"; shoot table "Reading list.md" 999 66 24 2.0 "2.592:type@24:\n| Book | Pages |\n| --- | --- |\n| The Peregrine | 191 |;3.764:key:tab" "" ;;
  pages) shoot pages "Reading list.md" 999 66 24 2.0 "2.58:pages;3.184:step;3.741:commit" "" ;;
  themes) shoot themes "Reading list.md" 999 122 24 2.0 "2.592:theme:ocean;3.184:theme:lavender;3.753:theme:graphite;4.357:theme:sepia;4.914:theme:moss;5.518:theme:frost;6.087:theme:paper" "" ;;
  carets) SIDEBAR=false shoot carets "Tuesday.md" 999 66 24 2.0 "2.58:shape:pin;2.882:shape:serif;3.184:shape:wedge;3.469:shape:ghost;3.753:shape:comet;4.043:shape:glow" "" ;;
  backdrops) shoot backdrops "Tuesday.md" 999 66 24 2.0 "2.58:backdrop:nebula;3.184:backdrop:ember;3.753:backdrop:borealis" "" ;;
  search) shoot search "Reading list.md" 999 66 24 2.0 "2.58:search:peregrine" "" ;;
  build) shoot build "Tuesday.md" 999 179 24 2.0 "2.581:review;3.166:style:book;3.754:style:bookDark;4.926:beside;5.511:select:999;5.531:type@50:\nOnward.;6.699:gallery;7.287:daily" "" ;;
  idle) shoot idle "Tuesday.md" 999 169 24 2.0 "42.323:esc" "" ;;
esac; }
case "${1:-all}" in
  lib) lib ;;
  all) lib; for s in write1 write paste table pages themes carets backdrops search build idle; do run "$s"; done ;;
  *) run "$1" ;;
esac
