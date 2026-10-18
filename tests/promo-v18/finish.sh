#!/usr/bin/env bash
# The deliverable from the master: H.264 1080p with the song at a broadcast-ish level, a poster from the end card, a 720p web encode.
set -euo pipefail
cd "$(dirname "$0")"
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH
OUT=../promo/glassine-promo-v18
mkdir -p ../promo
# loudness: measure, then bring to about -16 LUFS with a true-peak ceiling
ffmpeg -v error -y -i master.mp4 -map 0:v -map 0:a -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -profile:v high -level 4.1 -r 30 -g 60 \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 -af "loudnorm=I=-16:TP=-1.5:LRA=11" -c:a aac -b:a 256k -ar 48000 -movflags +faststart "$OUT.mp4"
ffmpeg -v error -y -ss 66.2 -i master.mp4 -frames:v 1 -q:v 2 "$OUT-poster.jpg"
ffmpeg -v error -y -i "$OUT.mp4" -vf scale=1280:720 -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart "$OUT-720.mp4"
ls -la "$OUT.mp4" "$OUT-720.mp4" "$OUT-poster.jpg"
