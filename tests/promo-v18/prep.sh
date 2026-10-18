#!/usr/bin/env bash
# v18 composition assets on the Mac: footage re-encoded for seeking, the glass looped, the cards cut, fonts and the wordmark, the song.
set -euo pipefail
cd "$(dirname "$0")"
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH
F=../promo-footage18; C=composition/assets
mkdir -p $C/footage $C/cards $C/fonts $C/img $C/music
for t in type timelapse review caret looks pages paste full; do
  [ -f $C/footage/$t.mp4 ] && [ $C/footage/$t.mp4 -nt $F/$t.mp4 ] || ffmpeg -v error -y -i $F/$t.mp4 -c:v libx264 -crf 15 -r 30 -g 15 -keyint_min 15 -pix_fmt yuv420p -movflags +faststart $C/footage/$t.mp4
done
# the glass: forward then back, so it never seams; long enough for the film
if [ ! -f $C/footage/glass-loop.mp4 ]; then
  ffmpeg -v error -y -i $F/glass.mp4 -vf "trim=0.5:11.5,setpts=PTS-STARTPTS" -c:v libx264 -crf 15 -g 15 -pix_fmt yuv420p /tmp/g1.mp4
  ffmpeg -v error -y -i /tmp/g1.mp4 -vf reverse -c:v libx264 -crf 15 -g 15 -pix_fmt yuv420p /tmp/g2.mp4
  printf "file '/tmp/g1.mp4'\nfile '/tmp/g2.mp4'\n%.0s" $(seq 1 4) > /tmp/gl.txt
  ffmpeg -v error -y -f concat -safe 0 -i /tmp/gl.txt -c:v libx264 -crf 15 -r 30 -g 15 -keyint_min 15 -pix_fmt yuv420p -movflags +faststart -t 80 $C/footage/glass-loop.mp4
fi
cp ../promo-v17/composition/assets/fonts/{Inter-Medium.otf,outfit-latin-200-normal.woff2,outfit-latin-300-normal.woff2} $C/fonts/
cp ../promo-v17/composition/assets/img/wordmark.png $C/img/
cp "$HOME/Projects/Glassine/.worktrees/main/dist/promo-v18/song.wav" $C/music/song.wav
# the cards, cut from the wall at 2x with the plate's rounded corners; Journal from the other picture (it was the selected card in the first)
/usr/bin/python3 - <<'PY'
import json
from PIL import Image, ImageDraw
cards=json.load(open('cards.json'))
w1=Image.open('../promo-footage18/wall/wall-0088.jpg').convert('RGBA'); w2=Image.open('../promo-footage18/wall2/wall2-0088.jpg').convert('RGBA')
for c in cards:
    src = w2 if c['id']=='Journal.md' else w1
    if c['id']=='Journal.md':
        # its place in the second picture, where another card is the selected one
        line=[l for l in open('wallframes2.txt') if l.startswith('Journal.md|')][0].strip().split('|')
        x,y,w,h = map(float, line[2:6])
    else:
        x,y,w,h = c['x'],c['y'],c['w'],c['h']
    box=(int(x*2),int(y*2),int((x+w)*2),int((y+h)*2))
    im=src.crop(box)
    m=Image.new('L',im.size,0); ImageDraw.Draw(m).rounded_rectangle([0,0,im.width-1,im.height-1],radius=28,fill=255)
    im.putalpha(m); im.save(f"composition/assets/cards/{c['slug']}.png")
print('cards cut', len(cards))
PY
ls -la $C/footage $C/cards | head -40
