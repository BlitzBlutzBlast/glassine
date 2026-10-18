"""Where does the picture actually change, near each moment it should?  python3 synccheck.py master.mp4 sync-events.json"""
import json, subprocess, sys, numpy as np
src, ev = sys.argv[1], json.load(open(sys.argv[2]))
w, h = 192, 108
raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', src, '-vf', f'scale={w}:{h}', '-f', 'rawvideo', '-pix_fmt', 'gray', '-'], capture_output=True).stdout
fr = np.frombuffer(raw, np.uint8).reshape(-1, h, w).astype(np.float32) / 255
def change(i):
    d = np.abs(fr[i] - fr[i - 1]); return d.reshape(12, 9, 16, 12).mean(axis=(1, 3)).max()
ch = np.array([0] + [change(i) for i in range(1, len(fr))])
noise = np.percentile(ch, 50); bad = 0
for t, what in ev:
    i0 = int(round(t * 30)); lo, hi = max(1, i0 - 4), min(len(fr) - 1, i0 + 5)
    seg = ch[lo:hi]; k = int(np.argmax(seg)); j = lo + k
    first = next((lo + m for m, v in enumerate(seg) if v > max(noise * 4, 0.03)), None)
    d = None if first is None else (first / 30 - t) * 1000
    flag = '' if d is not None and -45 <= d <= 40 else '  <--'
    bad += bool(flag)
    print(f"{t:7.3f} {what:22s} first change {('-' if d is None else f'{d:+5.0f} ms')}  peak {((j/30 - t)*1000):+5.0f} ms  size {seg.max():.3f}{flag}")
print('flagged', bad, 'of', len(ev))
# stillness: longest run of near-still frames before the fade
still = ch < max(noise * 1.5, 0.004); run = best = 0; where = 0
for i, s in enumerate(still[:int(76 * 30)]):
    run = run + 1 if s else 0
    if run > best: best, where = run, i
print('longest still run', best, 'frames ending at', round(where / 30, 2), 's')
