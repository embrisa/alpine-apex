"""Original Alpine Apex boot sound. No source recordings or external libraries.

Seeded filtered wind, bowed ice partials and one soft low impact; 24 kHz PCM16.
The sole impact is aligned to 0.82 seconds in the exposure reveal. No loops.
"""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 24000
DURATION = 2.13
DEST = Path(__file__).resolve().parents[2] / "assets/audio/interface/startup_ice.wav"


def build():
    rng = random.Random(14092026)
    channels = [[], []]
    low = mid = 0.0
    for i in range(round(RATE * DURATION)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low += 0.018 * (noise - low)
        mid += 0.20 * (noise - mid)
        swell = math.sin(math.pi * min(t / 1.9, 1)) ** 1.8
        gust = (0.5 + 0.5 * math.sin(t * 2.4 - 0.8)) ** 3
        wind = (low * 1.8 + (mid - low) * 0.32) * swell * (0.3 + 0.28 * gust)
        a = max(0, t - 0.82)
        impact = 0.0
        ice = 0.0
        if t > 0.82:
            attack = 1 - math.exp(-a * 100)
            impact = (math.sin(math.tau * (52 * a + 6 * (1 - math.exp(-a * 6))))
                      + 0.22 * math.sin(math.tau * 104 * a)) * math.exp(-a * 7) * attack * 0.18
            for k, freq in enumerate([861, 1379, 2111, 3023, 4817]):
                ice += math.sin(math.tau * freq * a) * math.exp(-a * (4 + k * 1.6)) / (k + 2)
            ice = ice * attack * 0.037 + (mid - low) * math.exp(-a * 19) * attack * 0.09
        fade = min(t / 0.035, 1) * min((DURATION - t) / 0.22, 1)
        for c in range(2):
            side = math.sin(t * 0.8 + c * 0.7) * 0.035
            channels[c].append((wind * (1 + side) + impact + ice) * fade)
    peak = max(abs(v) for channel in channels for v in channel)
    gain = 10 ** (-8 / 20) / peak
    data = bytearray()
    for i in range(len(channels[0])):
        data.extend(struct.pack("<hh", *(round(channel[i] * gain * 32767) for channel in channels)))
    DEST.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(DEST), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data)
    print(f"{DEST}: {len(data)} PCM bytes, {DURATION}s, peak -8 dBFS")


if __name__ == "__main__":
    build()
