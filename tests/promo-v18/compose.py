#!/usr/bin/env python3
"""v18 composition: the pieces of the app on its own glass, on the song's grid.
Writes composition/index.html (Hyperframes + GSAP). Run on the Mac after prep.sh."""
import json, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
P = 0.46342                     # a beat
PH = [2.278, 5.985, 9.693, 13.4, 17.107, 20.815, 24.522, 28.229, 31.937, 35.644, 39.351, 43.059, 46.766, 50.473, 54.181, 57.888, 61.595, 65.303, 69.01, 72.717, 76.425]
def B(p, b=0): return PH[p] + b * P
DUR = 78.0
LEAD = 2.0
T0 = json.load(open(os.path.join(HERE, "t0.json")))
# film time at which each take's script clock reads 0 (take start = first beat - LEAD, see plan18)
START = {"type": PH[0] - 0.3 - LEAD, "timelapse": B(7) - 0.4 - LEAD, "review": B(9) - 0.4 - LEAD, "caret": B(10) - 0.4 - LEAD,
         "looks": B(12) - 0.4 - LEAD, "pages": B(13) - 0.4 - 3 * P - LEAD, "paste": B(14) - 0.6 - LEAD}
# the picture shows the frame at or before its time: start every clip half a frame on, plus the app's own lag
LAG = 1 / 60 + 0.03

TRIM = {"type": 0.02, "timelapse": 0.045, "review": 0.035, "caret": 0.03, "looks": -0.01, "pages": 0.085, "paste": 0.0}
def media_start(take, film_t):
    """media time of take at film time film_t"""
    return film_t - START[take] - T0[take] + LAG + TRIM.get(take, 0)

# ---- the wall -------------------------------------------------------------------------------
K = 1.5                                  # window points -> film px
cards = []
for line in open(os.path.join(HERE, "wallframes.txt")):
    p = line.strip().split("|")
    if len(p) < 6: continue
    cards.append({"id": p[0], "title": p[1], "x": float(p[2]), "y": float(p[3]), "w": float(p[4]), "h": float(p[5])})
X0, Y0 = 28.0, 102.0
WALL_W = max(c["x"] + c["w"] for c in cards) - X0
WALL_H = max(c["y"] + c["h"] for c in cards) - Y0
OX = (1920 - WALL_W * K) / 2
OY = (1080 - WALL_H * K) / 2
def px(c): return (OX + (c["x"] - X0) * K, OY + (c["y"] - Y0) * K, c["w"] * K, c["h"] * K)
# the carry: Ideas leaves its column (the cards under it close up) and goes under Chapter one (the cards there make room)
GAP = 14.0
moved = next(c for c in cards if c["id"] == "Ideas.md")
after = {}
for c in cards:
    x, y = c["x"], c["y"]
    if c["id"] == "Ideas.md":
        top = next(k for k in cards if k["id"] == "Chapter one.md")
        x, y = top["x"], top["y"] + top["h"] + GAP
    elif c["x"] == moved["x"] and c["y"] > moved["y"]:
        y -= moved["h"] + GAP
    elif c["x"] == 955.0 and c["y"] > 102.0:
        y += moved["h"] + GAP
    after[c["id"]] = (OX + (x - X0) * K, OY + (y - Y0) * K)
slug = lambda s: "".join(ch if ch.isalnum() else "-" for ch in s.replace(".md", "")).strip("-").lower()

# ---- clips: (take, film start, film end, camera) ; camera = (scale, source cx, source cy) in 2x px --------
CLIPS = [
    ("type",      0.0,    B(5),        (1.5, 950, 672)),
    ("timelapse", B(7),   B(9),        (1.22, 1280, 900)),
    ("review",    B(9),   B(10),       (1.14, 1280, 860)),
    ("caret",     B(10),  B(12),       (2.2, 900, 790)),
    ("looks",     B(12),  B(13),       (0.78, 1280, 860)),
    ("pages",     B(13),  B(14),       (1.15, 1280, 838)),
    ("paste",     B(14),  B(15),       (1.12, 1280, 880)),
]
def cam_css(scale, cx, cy):
    # a 2560x1600 video, scaled about its top-left, placed so (cx, cy) sits at the frame's centre
    return f"transform: translate({960 - cx * scale:.1f}px, {540 - cy * scale:.1f}px) scale({scale:.4f});"

videos, shows = [], []
for i, (take, t0, t1, cam) in enumerate(CLIPS):
    ms = media_start(take, t0)
    if ms < 0:            # the take has less lead than the film: it joins when its first frame is due
        t0, ms = t0 - ms, 0.0
    videos.append(f'<div class="clip" id="k{i}" style="{cam_css(*cam)}"><video id="v{i}" src="assets/footage/{take}.mp4" data-start="{t0:.4f}" data-duration="{t1 - t0 + 0.2:.4f}" data-media-start="{ms:.4f}" data-track-index="{i % 2 + 1}" muted playsinline preload="auto"></video></div>')
    shows.append((f"#k{i}", t0, t1))

cards_html = "\n".join(
    f'<img class="card" id="card-{slug(c["id"])}" src="assets/cards/{slug(c["id"])}.png" style="left:{px(c)[0]:.1f}px; top:{px(c)[1]:.1f}px; width:{px(c)[2]:.1f}px; height:{px(c)[3]:.1f}px;">'
    for c in cards)

# ---- the timeline ----------------------------------------------------------------------------
tl = []
def add(s): tl.append("  " + s)
# clips: on at their start, off at their end (hard cuts on downbeats)
for sel, t0, t1 in shows:
    if sel == "#k0":      # the page fades up out of the bare glass
        add(f'tl.fromTo("{sel}", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.6, ease: "sine.inOut", immediateRender: false }}, {t0:.4f});')
    else:
        add(f'tl.set("{sel}", {{ opacity: 1 }}, {t0:.4f});')
    add(f'tl.set("{sel}", {{ opacity: 0 }}, {t1:.4f});')
# slow pushes inside the long full-bleed shots (the picture never stands still)
add(f'tl.fromTo("#k0 video", {{ scale: 1.0 }}, {{ scale: 1.04, duration: {B(4) - 0.2:.3f}, ease: "sine.inOut", transformOrigin: "950px 672px" }}, 0.2);')
# the build under the riser: the push gathers toward the drop
add(f'tl.to("#k0 video", {{ scale: 1.16, duration: {B(5) - B(4) - 0.15:.3f}, ease: "power2.in", transformOrigin: "950px 672px" }}, {B(4):.3f});')
add(f'tl.fromTo("#k1 video", {{ scale: 1.0 }}, {{ scale: 1.05, duration: {B(9) - B(7):.3f}, ease: "sine.inOut", transformOrigin: "1280px 900px" }}, {B(7):.3f});')
add(f'tl.fromTo("#k2 video", {{ scale: 1.0 }}, {{ scale: 1.04, duration: {B(10) - B(9):.3f}, ease: "sine.inOut", transformOrigin: "1280px 860px" }}, {B(9):.3f});')
add(f'tl.fromTo("#k3 video", {{ scale: 1.0 }}, {{ scale: 1.05, duration: {B(12) - B(10):.3f}, ease: "sine.inOut", transformOrigin: "900px 790px" }}, {B(10):.3f});')
add(f'tl.fromTo("#k5 video", {{ scale: 1.0 }}, {{ scale: 1.05, duration: {B(14) - B(13):.3f}, ease: "sine.inOut", transformOrigin: "1280px 760px" }}, {B(13):.3f});')
add(f'tl.fromTo("#k6 video", {{ scale: 1.0 }}, {{ scale: 1.04, duration: {B(15) - B(14):.3f}, ease: "sine.inOut", transformOrigin: "1280px 880px" }}, {B(14):.3f});')
# the opening: from black
add('tl.fromTo("#fade", { opacity: 1 }, { opacity: 0, duration: 1.4, ease: "sine.out", immediateRender: false }, 0);')

# the drop: the page becomes the wall. The page shrinks toward Draft's place and fades; Draft is there; the rest arrive on eighths.
dx, dy, dw, dh = px(next(c for c in cards if c["id"] == "Draft.md"))
add(f'tl.to("#k0", {{ opacity: 0, duration: 0.28, ease: "power2.in" }}, {B(5) - 0.1:.4f});')
add(f'tl.to("#k0 video", {{ scale: 0.6, duration: 0.3, ease: "power3.in", transformOrigin: "950px 672px", overwrite: "auto" }}, {B(5) - 0.14:.4f});')
add(f'tl.set("#wall", {{ opacity: 1 }}, {B(5) - 0.02:.4f});')
# arrival order: reading order (top-left first), Draft first on the downbeat
order = sorted(cards, key=lambda c: (c["y"], c["x"]))
t = B(5)
for n, c in enumerate(order):
    sel = f"#card-{slug(c['id'])}"
    cx, cy, cw, ch = px(c)
    fromx = -700 if cx + cw / 2 < 960 else 700
    when = t if c["id"] == "Draft.md" else t + (n * P / 2)
    if c["id"] == "Draft.md":
        add(f'tl.fromTo("{sel}", {{ opacity: 0, scale: 1.6 }}, {{ opacity: 1, scale: 1, duration: 0.32, ease: "expo.out", immediateRender: false }}, {when:.4f});')
    else:
        add(f'tl.fromTo("{sel}", {{ opacity: 0, x: {fromx * 0.35:.0f}, y: 140, scale: 1.08 }}, {{ opacity: 1, x: 0, y: 0, scale: 1, duration: 0.36, ease: "expo.out", immediateRender: false }}, {when - 1 / 30:.4f});')
# the carry: Ideas lifts on the downbeat, crosses, lands on the next; the others close up / make room halfway
sel = "#card-ideas"
ix, iy, iw, ih = px(moved); ax, ay = after["Ideas.md"]
add(f'tl.set("{sel}", {{ zIndex: 5 }}, {B(6) - 0.05:.4f});')
add(f'tl.to("{sel}", {{ scale: 1.045, boxShadow: "0 30px 70px rgba(0,0,0,0.55)", duration: 0.26, ease: "power2.out" }}, {B(6) - 1 / 30:.4f});')
# an arc: up and over, eased like a hand
add(f'tl.to("{sel}", {{ x: {(ax - ix) * 0.55:.1f}, y: {(ay - iy) * 0.3 - 46:.1f}, duration: {3 * P:.3f}, ease: "sine.inOut" }}, {B(6, 1):.4f});')
add(f'tl.to("{sel}", {{ x: {ax - ix:.1f}, y: {ay - iy:.1f}, duration: {3 * P:.3f}, ease: "sine.inOut" }}, {B(6, 4):.4f});')
add(f'tl.to("{sel}", {{ scale: 1, boxShadow: "0 0 0 rgba(0,0,0,0)", duration: 0.22, ease: "power3.out" }}, {B(7) - 0.22:.4f});')
for c in cards:
    if c["id"] == "Ideas.md": continue
    bx, by, _, _ = px(c); nx, ny = after[c["id"]]
    if abs(nx - bx) > 0.5 or abs(ny - by) > 0.5:
        add(f'tl.to("#card-{slug(c["id"])}", {{ x: {nx - bx:.1f}, y: {ny - by:.1f}, duration: 0.55, ease: "back.out(1.2)" }}, {B(6, 4) - 0.05:.4f});')
# the wall gives way to the Timelapse on the downbeat
add(f'tl.to("#wall", {{ opacity: 0, scale: 0.94, duration: 0.3, ease: "power2.in", transformOrigin: "960px 540px" }}, {B(7) - 0.02:.4f});')
add(f'tl.set("#wall", {{ opacity: 0 }}, {B(7) + 0.3:.4f});')

# the keys: one glyph a beat before the thing it does
def key(glyph, when, hold=P * 1.6):
    add(f'tl.set("#keytext", {{ innerText: "{glyph}" }}, {when - 0.02:.4f});')
    add(f'tl.fromTo("#key", {{ opacity: 0, y: 10, scale: 0.96 }}, {{ opacity: 1, y: 0, scale: 1, duration: 0.16, ease: "power2.out", immediateRender: false }}, {when:.4f});')
    add(f'tl.to("#key", {{ opacity: 0, duration: 0.18, ease: "power2.in" }}, {when + hold:.4f});')
key("⌘1", B(5) - P)
key("⌘2", B(7) - P)
key("⌘↩", B(9) - P)
key("⌥⇥", B(13) - P)
key("⌘V", B(14) - P)

# the whole window, once: it comes forward on the big phrase, and recedes into the glass on the quiet one
add(f'tl.fromTo("#full", {{ opacity: 0, scale: 0.58 }}, {{ opacity: 1, scale: 0.65, duration: 0.5, ease: "expo.out", immediateRender: false }}, {B(15) - 1 / 30:.4f});')
add(f'tl.to("#full", {{ scale: 0.585, y: -14, duration: {B(16) - B(15) - 0.5:.3f}, ease: "sine.inOut" }}, {B(15) + 0.5:.4f});')
add(f'tl.to("#full", {{ opacity: 0, scale: 0.5, duration: 0.9, ease: "power2.in", overwrite: "auto" }}, {B(16) - 1 / 30:.4f});')
# the end: the wordmark on the hit, the line on the quiet downbeat, the address on the last hit; then the ring-out
add(f'tl.set("#end", {{ opacity: 1 }}, {B(17) - 0.1:.4f});')
add(f'tl.fromTo("#mark", {{ opacity: 0, scale: 1.18, filter: "blur(10px)" }}, {{ opacity: 1, scale: 1, filter: "blur(0px)", duration: 0.55, ease: "expo.out", immediateRender: false }}, {B(17) - 1 / 30:.4f});')
add(f'tl.fromTo("#tag1", {{ opacity: 0, y: 16 }}, {{ opacity: 1, y: 0, duration: 0.5, ease: "expo.out", immediateRender: false }}, {B(18) - 1 / 30:.4f});')
add(f'tl.fromTo("#tag2", {{ opacity: 0, y: 16 }}, {{ opacity: 1, y: 0, duration: 0.5, ease: "expo.out", immediateRender: false }}, {B(19) - 1 / 30:.4f});')
add(f'tl.to("#end", {{ y: -8, duration: 3.2, ease: "sine.inOut", yoyo: true, repeat: 3 }}, {B(17):.4f});')
add(f'tl.to("#fade", {{ opacity: 1, duration: 1.0, ease: "power2.in" }}, {DUR - 1.2:.4f});')

html = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=1920, height=1080" />
<title>Glassine — v18 (Seasonal Mania)</title>
<script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>
<style>
  @font-face {{ font-family: "Outfit"; src: url("assets/fonts/outfit-latin-200-normal.woff2") format("woff2"); font-weight: 200; }}
  @font-face {{ font-family: "Outfit"; src: url("assets/fonts/outfit-latin-300-normal.woff2") format("woff2"); font-weight: 300; }}
  @font-face {{ font-family: "Inter"; src: url("assets/fonts/Inter-Medium.otf") format("opentype"); font-weight: 500; }}
  html, body {{ margin: 0; background: #0a0a14; }}
  #root {{ position: relative; width: 1920px; height: 1080px; overflow: hidden; background: #0a0a14; font-family: "Outfit", sans-serif; -webkit-font-smoothing: antialiased; }}
  /* the glass: the app's own backdrop, full bleed, the chrome cropped off the top */
  #glass {{ position: absolute; left: 0; top: -90px; width: 1920px; height: 1200px; }}
  #glass video {{ width: 1920px; height: 1200px; object-fit: fill; }}
  .clip {{ position: absolute; left: 0; top: 0; width: 2560px; height: 1600px; transform-origin: 0 0; opacity: 0; }}
  .clip video {{ position: absolute; left: 0; top: 0; width: 2560px; height: 1600px; object-fit: fill; }}
  #wall {{ position: absolute; left: 0; top: 0; width: 1920px; height: 1080px; opacity: 0; }}
  .card {{ position: absolute; opacity: 0; border-radius: 21px; transform-origin: 50% 50%; }}
  #full {{ position: absolute; left: 50%; top: 50%; width: 2560px; height: 1600px; margin: -800px 0 0 -1280px; border-radius: 28px; overflow: hidden; opacity: 0;
           box-shadow: 0 60px 160px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.07); transform-origin: 50% 50%; }}
  #full video {{ width: 2560px; height: 1600px; object-fit: fill; }}
  #key {{ position: absolute; left: 50%; bottom: 84px; transform: translateX(-50%); padding: 14px 26px; border-radius: 18px; opacity: 0;
          background: rgba(12,10,26,0.55); border: 1px solid rgba(255,255,255,0.14); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px);
          color: #eef1fa; font-family: "Inter", sans-serif; font-weight: 500; font-size: 46px; letter-spacing: 0.06em; }}
  #end {{ position: absolute; left: 50%; top: 50%; width: 1152px; height: 420px; margin: -236px 0 0 -576px; opacity: 0; }}
  #mark {{ position: absolute; left: 0; top: 0; width: 1152px; height: 260px; background: url("assets/img/wordmark.png") center / contain no-repeat; opacity: 0; }}
  #tag1, #tag2 {{ position: absolute; left: 0; right: 0; text-align: center; opacity: 0; letter-spacing: 0.04em; font-weight: 300; }}
  #tag1 {{ top: 296px; font-size: 32px; color: #f0f4ff; }}
  #tag2 {{ top: 352px; font-size: 20px; color: #8dbbff; }}
  #fade {{ position: absolute; inset: 0; background: #000; opacity: 0; }}
</style>
</head>
<body>
<div id="root" data-composition-id="glassine-v18" data-start="0" data-width="1920" data-height="1080" data-duration="{DUR}">
  <div id="glass"><video id="vglass" src="assets/footage/glass-loop.mp4" data-start="0" data-duration="{DUR}" data-media-start="0" data-track-index="3" muted playsinline preload="auto"></video></div>
  <div id="fontwarm" style="position:absolute;left:0;top:0;opacity:0;font-family:Outfit"><span style="font-weight:200">a</span><span style="font-weight:300">a</span><span style="font-family:Inter;font-weight:500">a</span></div>
  {chr(10).join("  " + v for v in videos)}
  <div id="wall">
{cards_html}
  </div>
  <div id="full"><video id="vfull" src="assets/footage/full.mp4" data-start="{B(15) - 0.2:.4f}" data-duration="{B(17) - B(15) + 0.4:.4f}" data-media-start="0.3" data-track-index="4" muted playsinline preload="auto"></video></div>
  <div id="key"><span id="keytext">⌘1</span></div>
  <div id="end">
    <div id="mark"></div>
    <div id="tag1">A quiet place to write.</div>
    <div id="tag2">glassine.ink · free and open source · on the Mac App Store</div>
  </div>
  <div id="fade"></div>
  <audio id="music" src="assets/music/song.wav" data-start="0" data-duration="{DUR}" data-track-index="10" data-volume="1"></audio>
</div>
<script>
for (const el of document.querySelectorAll("#root *")) {{ el.setAttribute("data-layout-allow-overlap", ""); el.setAttribute("data-layout-allow-occlusion", ""); el.setAttribute("data-layout-allow-overflow", ""); }}
function build() {{
  const tl = gsap.timeline({{ paused: true }});
{chr(10).join(tl)}
  window.__timelines = window.__timelines || {{}};
  window.__timelines["glassine-v18"] = tl;
  if (window.__hfForceTimelineRebind) window.__hfForceTimelineRebind();
}}
Promise.all([document.fonts.ready, document.fonts.load("300 100px Outfit"), document.fonts.load("500 40px Inter")]).then(build);
</script>
</body>
</html>
'''
os.makedirs(os.path.join(HERE, "composition"), exist_ok=True)
open(os.path.join(HERE, "composition", "index.html"), "w").write(html)
json.dump([{"id": c["id"], "slug": slug(c["id"]), "x": c["x"], "y": c["y"], "w": c["w"], "h": c["h"]} for c in cards], open(os.path.join(HERE, "cards.json"), "w"), indent=1)
print("wrote composition/index.html;", len(cards), "cards; wall", round(WALL_W * K), "x", round(WALL_H * K), "at", round(OX), round(OY))
