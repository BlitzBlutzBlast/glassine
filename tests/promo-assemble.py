#!/usr/bin/env python3
"""Join a self-shot's timestamped frames into a 30 fps film on the script's clock.

    promo-assemble.py <frames dir> <stem> <out.mp4> [anchors.json]

Reads <stem>-times.txt ("f i t" per frame, "a t at kind arg" per action), writes a
concat list whose durations are the real gaps between frames, and resamples to
30 fps, so a frame shot at script time t is at t - t0 in the film (t0 = the first
frame's time). With anchors ([{onset, beat}] in script seconds) the clock is warped
piecewise-linearly so each onset lands on its beat: the app's own timing jitter
(an action firing a few tens of ms late) is taken out, and nothing else changes.
"""
import json, os, subprocess, sys

frames_dir, stem, out = sys.argv[1], sys.argv[2], sys.argv[3]
anchors = json.load(open(sys.argv[4])) if len(sys.argv) > 4 else []
frames, actions = [], []
for line in open(os.path.join(frames_dir, stem + "-times.txt")):
    p = line.split()
    if not p: continue
    if p[0] == "f": frames.append((int(p[1]), float(p[2])))
    elif p[0] == "a": actions.append({"fired": float(p[1]), "at": float(p[2]), "kind": p[3], "arg": " ".join(p[4:])})
frames.sort()
pts = sorted((a["onset"], a["beat"]) for a in anchors)
def warp(t):
    if not pts: return t
    if t <= pts[0][0]: return t + pts[0][1] - pts[0][0]
    if t >= pts[-1][0]: return t + pts[-1][1] - pts[-1][0]
    for (o0, b0), (o1, b1) in zip(pts, pts[1:]):
        if o0 <= t <= o1: return b0 + (t - o0) * (b1 - b0) / (o1 - o0)
slopes = [(b1 - b0) / (o1 - o0) for (o0, b0), (o1, b1) in zip(pts, pts[1:]) if o1 > o0]
times = [(i, warp(t)) for i, t in frames]
ext = "jpg" if os.path.exists(os.path.join(frames_dir, f"{stem}-0000.jpg")) else "png"
lst = os.path.join(frames_dir, stem + "-list.txt")
with open(lst, "w") as f:
    f.write("ffconcat version 1.0\n")
    for k, (i, t) in enumerate(times):
        f.write(f"file '{stem}-{i:04d}.{ext}'\n")
        dur = (times[k + 1][1] - t) if k + 1 < len(times) else 1 / 30
        f.write(f"duration {max(dur, 0.001):.5f}\n")
    f.write(f"file '{stem}-{times[-1][0]:04d}.{ext}'\n")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst,
                "-vf", "fps=30:round=near,scale=2560:1600", "-c:v", "libx264", "-crf", "14", "-pix_fmt", "yuv420p", out], check=True)
info = {"t0": times[0][1], "frames": len(frames), "warped": bool(pts),
        "slopes": [round(s, 3) for s in slopes], "actions": actions}
json.dump(info, open(out.rsplit(".", 1)[0] + ".json", "w"), indent=1)
print(f"{stem}: {len(frames)} frames, t0 {times[0][1]:.3f}, anchors {len(pts)}, speed range "
      f"{(min(slopes) if slopes else 1):.3f}..{(max(slopes) if slopes else 1):.3f}")
