#!/usr/bin/env bash
# The direct build launched on a scratch library and driven by key presses
# through System Events, aimed at that copy alone (by its process id, never
# the copy in /Applications), with the footer read back after each press.
#   ./tests/keys.sh carousel      three pages open; ⌥Tab twice, Esc, ⌘W
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/Glassine.app"
LIB=/tmp/glassine-shot-library-syntax
[[ -d "$LIB" ]] || ./tests/shot-syntax.sh table >/dev/null 2>&1 || true
pkill -f "$APP/Contents/MacOS/Glassine" 2>/dev/null || true
json='{"sidebarVisible":false,"themeID":"dusk","appearanceMode":"fixed","libraryPath":"'"$LIB"'","lastOpenedDocument":"Rule.md"}'
b64=$(printf '%s' "$json" | base64 | tr -d '\n')
case "${1:-carousel}" in
  carousel) view=carousel ;;
  *) view="$1" ;;
esac
open -n "$APP" --args -glassine.launchWindow 1000x700 -glassine.launchView "$view" -glassine.launchSettings "$b64"
sleep 4
PID=$(pgrep -f "$APP/Contents/MacOS/Glassine" | head -1)
footer() {
  osascript -e "tell application \"System Events\" to tell (first process whose unix id is $PID) to get value of every static text of group 1 of window 1" 2>&1 | tr -s ' '
}
press() {  # press "key code 48 using option down"
  osascript -e "tell application \"System Events\" to tell (first process whose unix id is $PID)" -e "set frontmost to true" -e "delay 0.3" -e "$1" -e "end tell" >/dev/null 2>&1
  sleep 1.2
}
echo "start:   $(footer)"
press "key code 53"
press "key code 48 using option down"; echo "⌥Tab:    $(footer)"
press "key code 48 using option down"; echo "⌥Tab:    $(footer)"
press "key code 48 using {option down, shift down}"; echo "⌥⇧Tab:   $(footer)"
press "keystroke \"w\" using command down"; echo "⌘W:      $(footer)"
pkill -f "$APP/Contents/MacOS/Glassine" 2>/dev/null || true
