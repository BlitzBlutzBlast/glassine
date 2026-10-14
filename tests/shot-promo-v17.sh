#!/usr/bin/env bash
# v17 footage, generated from the song's bar grid: every action on a beat.
# bash tests/shot-promo-v17.sh [all|<shot>]
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
. tests/shot-promo-v17-lib.sh
run() { case "$1" in
  intro) printf '%b' ' ' > "$LIB/Tuesday.md"; shoot17 intro "Tuesday.md" 0 14.073 "4.783:type@0:A;5.218:type@0: quiet;5.701:type@0: place;6.15:type@0: to;7.149:type@0: write." ;;
  write) printf '%b' 'A quiet place to write.' > "$LIB/Tuesday.md"; shoot17 write "Tuesday.md" 999 11.654 "1.951:type@0:\n;2.527:type@0:Started;3.161:type@0: @today;3.195:type@0: ;4.346:type@0:\n- [ ] Call mom;5.475:type@0:\nWater the plants;6.671:task:0;9.014:end:;9.035:type@0:\n\nFinish the;9.612:type@0: **draft**;10.191:type@0: tonight." ;;
  build) printf '%b' 'A quiet place to write.\nStarted @October 14, 2026\n- [ ] Water the plants\n- [x] Call mom\n\nFinish the **draft** tonight.' > "$LIB/Tuesday.md"; HIDE=true shoot17 build "Tuesday.md" 999 11.65 "1.83:review:;4.315:style:github;4.876:style:book;5.497:style:bookDark;6.073:style:mono;6.601:style:bookDark;6.604:review:;6.606:beside:;7.817:end:;7.82:type@0:\nOnward.;8.971:daily:;9.574:walk:1;10.182:walk:1;10.737:walk:1" ;;
  paste) printf '%b' '# Reading list\n' > "$LIB/Reading list.md"; FOCUS=false TYPEWRITER=false shoot17 paste "Reading list.md" 999 6.929 "0.5:warm:;1.94:pastehtml:shopping;4.272:type@0:\n\n;4.274:pastehtml:table;4.371:select:0" ;;
  pages) printf '%b' '# Reading list\n\n## Shopping\n\n- Milk\n- **Eggs**, a dozen\n\n| Book | Pages |\n| --- | --- |\n| The Peregrine | 191 |\n| Pilgrim at Tinker Creek | 290 |' > "$LIB/Reading list.md"; FOCUS=false TYPEWRITER=false shoot17 pages "Reading list.md" 999 6.952 "0.4:pages:;1.0:open:Reading list.md;1.905:step:;3.113:step:;4.268:commit:;5.477:prev:" ;;
  themes) printf '%b' '# Reading list\n\n## Shopping\n\n- Milk\n- **Eggs**, a dozen\n\n| Book | Pages |\n| --- | --- |\n| The Peregrine | 191 |\n| Pilgrim at Tinker Creek | 290 |' > "$LIB/Reading list.md"; FOCUS=false TYPEWRITER=false shoot17 themes "Reading list.md" 999 6.906 "2.509:theme:ocean;3.101:theme:lavender;3.705:theme:graphite;4.277:theme:sepia-night;4.85:theme:moss;5.457:theme:frost;5.977:theme:paper" ;;
  backdrops) FROST=0.12 shoot17 backdrops "On Writing Slowly.md" 999 6.928 "2.54:backdrop:nebula;3.131:backdrop:ember;3.703:backdrop:borealis;4.287:backdrop:rose;4.869:backdrop:sunset;5.449:backdrop:ocean;6.035:backdrop:moss" ;;
  library) rm -f "$LIB/Tuesday.md"; printf '%b' '# Reading list\n\n## Shopping\n\n- Milk\n- **Eggs**, a dozen\n\n| Book | Pages |\n| --- | --- |\n| The Peregrine | 191 |\n| Pilgrim at Tinker Creek | 290 |' > "$LIB/Reading list.md"; printf '%b' 'A quiet place to write.\nStarted @October 14, 2026\n- [ ] Water the plants\n- [x] Call mom\n\nFinish the **draft** tonight.' > "$LIB/Draft.md"; HIDE=true shoot17 library "Draft.md" 999 6.918 "2.489:gallery:;4.28:card:Morning pages.md;5.404:esc:" ;;
  caret) printf '%b' ' ' > "$LIB/Field notes.md"; CARETW=6 shoot17 caret "Field notes.md" 0 6.917 "1.952:type@0:One;2.524:type@0: word;3.124:type@0: at a;3.679:type@0: time.;4.277:shape:pin;4.857:shape:comet;5.449:shape:glow;6.018:shape:bar" ;;
  end) printf '%b' 'A quiet place to write.' > "$LIB/Tuesday.md"; shoot17 end "Tuesday.md" 999 9.216 "1.954:type@0:\n\nFree.;4.274:type@0: Open source." ;;
esac; }
case "${1:-all}" in
  lib) lib ;;
  all) for s in intro write build paste pages themes backdrops library caret end; do lib; run "$s"; done ;;
  *) lib; run "$1" ;;
esac
