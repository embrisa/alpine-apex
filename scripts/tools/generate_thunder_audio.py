"""Deterministic original thunder assets. Offline only; no third-party source audio."""
import json
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio/weather"

def generate():
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    for clip in range(3):
        rng = random.Random(849205174 + clip)
        rate, seconds = 24000, 7 + clip
        low, mid, previous, dc = 0.0, 0.0, 0.0, 0.0
        samples = []
        for i in range(rate * seconds):
            t = i / rate
            noise = rng.uniform(-1, 1)
            low += .027 * (noise - low)
            mid += .14 * (noise - mid)
            onset = min(1.0, t / .065)
            tail = math.exp(-t / (1.7 + .3 * clip)) * min(1.0, (seconds-t)/.8)
            roll = .65 + .22 * math.sin(t * 3.1 + clip) + .13 * math.sin(t * 7.7)
            value = (low * 3.1 + mid * .5 * math.exp(-t*2) + .045 * math.sin(t*math.tau*39)) * onset * tail * roll
            # DC blocker and a conservative asset ceiling, verified below.
            dc = value - previous + .995 * dc
            previous = value
            samples.append(dc)
        gain = .50 / max(abs(v) for v in samples)
        pcm = [round(v * gain * 32767) for v in samples]
        path = OUT / f"thunder_{clip+1:02d}.wav"
        with wave.open(str(path), "wb") as output:
            output.setparams((1, 2, rate, 0, "NONE", "not compressed"))
            output.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))
        rows.append({"file":path.name,"seconds":seconds,"peak_dbfs":20*math.log10(max(abs(v) for v in pcm)/32768),"rms":math.sqrt(sum(v*v for v in pcm)/len(pcm))/32768,"mean":sum(pcm)/len(pcm)/32768})
    print(json.dumps(rows, indent=2))

if __name__ == "__main__":
    generate()
