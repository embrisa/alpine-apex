"""Reproducible mono PCM rain loop; no sample synthesis during rendering."""
from array import array
from pathlib import Path
import math
import random
import wave

rate = 22050
count = rate * 8
rng = random.Random(7321)
low = 0.0
samples = []
for i in range(count):
    noise = rng.uniform(-1.0, 1.0)
    low += (noise - low) * 0.2
    envelope = 0.85 + 0.10 * math.sin(2 * math.pi * i / count)
    samples.append((noise * 0.17 + low * 0.30) * envelope)
# Soft individual patter spread throughout the loop, including its seam.
for _ in range(1600):
    start = rng.randrange(count)
    amplitude = rng.uniform(0.02, 0.11)
    for offset in range(100):
        samples[(start + offset) % count] += amplitude * math.exp(-offset / 13) * rng.uniform(-1, 1)
# Crossfade the tail into the beginning for a click-free periodic join.
fade = rate // 10
for i in range(fade):
    weight = i / fade
    samples[count - fade + i] = samples[count - fade + i] * (1-weight) + samples[i] * weight
samples = samples[fade:]
pcm = array('h', (int(max(-0.95, min(0.95, s)) * 32767) for s in samples))
import sys
if sys.byteorder != 'little':
    pcm.byteswap()
with wave.open(str(Path(__file__).resolve().parents[2] / 'assets/rain.wav'), 'wb') as output:
    output.setparams((1, 2, rate, len(pcm), 'NONE', 'not compressed'))
    output.writeframes(pcm.tobytes())
