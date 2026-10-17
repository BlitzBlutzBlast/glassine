#!/usr/bin/env bash
# The app photographs its own glass for the icon: a look's theme over its
# backdrop, the sidebar hidden, a blank page, the caret not blinking. Writes
# Resources/glass-<backdrop>.jpg (a JPEG: the grain makes a PNG five times the
# size, and the icon is a quarter of the picture's width anyway); then `python3 Resources/make_icon.py --glass
# <backdrop>` draws the icon on it. Run against the installed app so nothing
# else has to build:
#   tests/shot-icon.sh [/Applications/Glassine.app]
# The look is Soft Sky, the one the app comes with; THEME, BACKDROP, FROST and
# GRAIN choose another (the aurora icon was THEME=dusk BACKDROP=aurora FROST=0.3
# GRAIN=0.08), and MOMENT the seconds the folds drift before the picture.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-/Applications/Glassine.app}"
THEME="${THEME:-midnight}"
BACKDROP="${BACKDROP:-softsky}"
FROST="${FROST:-0.2}"
GRAIN="${GRAIN:-0.085}"
MOMENT="${MOMENT:-5}"
LIB=/tmp/glassine-shot-library-icon
T="$(getconf DARWIN_USER_TEMP_DIR)glassine-shots"
rm -rf "$LIB"; mkdir -p "$LIB"; printf '\n' > "$LIB/Blank.md"
mkdir -p "$T"
name="icon-$BACKDROP"
rm -f "$T/$name.png" "$T/$name.png.status"
json='{"sidebarVisible":false,"typewriterMode":false,"focusMode":false,"showCounter":false,"themeID":"'"$THEME"'","appearanceMode":"fixed","backdrop":"'"$BACKDROP"'","backdropFrost":'"$FROST"',"backdropGrain":'"$GRAIN"',"caretBlink":"none","libraryPath":"'"$LIB"'","lastOpenedDocument":"Blank.md","tourSeen":true}'
b64=$(printf '%s' "$json" | base64 | tr -d '\n')
open -n "$APP" --args -glassine.shoot "$name.png" -glassine.launchWindow 1200x860 -glassine.shootDelay "$MOMENT" -glassine.launchSettings "$b64"
w=0; until [[ -f "$T/$name.png.status" ]]; do sleep 0.5; w=$((w+1)); (( w > 60 )) && { echo "no status"; exit 1; }; done
cat "$T/$name.png.status"; echo
sips -s format jpeg -s formatOptions 94 "$T/$name.png" --out "Resources/glass-$BACKDROP.jpg" >/dev/null
echo "wrote Resources/glass-$BACKDROP.jpg"
