"""Signal evidence and audition index; does not claim subjective listening."""
import json
import math
import wave
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/sfx"
results = []
for path in sorted(OUT.rglob("*.wav")):
    with wave.open(str(path), "rb") as wav:
        if wav.getsampwidth() != 2:
            continue
        channels, rate = wav.getnchannels(), wav.getframerate()
        samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").astype(np.float64) / 32768
    frames = samples.reshape(-1, channels)
    rms = float(np.sqrt(np.mean(frames ** 2)))
    mono = frames.mean(axis=1)
    peak = float(np.max(np.abs(frames)))
    result = {
        "file": path.relative_to(OUT).as_posix(), "seconds": len(frames) / rate,
        "sample_rate": rate, "channels": channels,
        "rms_dbfs": 20 * math.log10(max(1e-12, rms)),
        "peak_dbfs": 20 * math.log10(max(1e-12, peak)),
        "dc": float(np.mean(frames)), "clipped_samples": int(np.sum(np.abs(frames) >= 32767 / 32768)),
        "mono_difference_db": 20 * math.log10(max(1e-12, float(np.sqrt(np.mean(mono**2)))) / max(1e-12, rms)),
    }
    results.append(result)
(OUT / "signal_analysis.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
lines = ["# Procedural sound auditions", "", "Four-second isolated scenes; final combined mix and device/crash captures are separate.", "",
         "| Clip | Seconds | RMS dBFS | Peak dBFS |", "| --- | ---: | ---: | ---: |"]
for item in results:
    lines.append(f"| [{item['file']}]({item['file']}) | {item['seconds']:.2f} | {item['rms_dbfs']:.2f} | {item['peak_dbfs']:.2f} |")
lines += ["", "Signal measurements verify finite levels and clipping/DC behavior. Naturalness, fatigue and gameplay balance need a listener."]
(OUT / "AUDITIONS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(json.dumps({"files": len(results), "clipped_samples": sum(r["clipped_samples"] for r in results)}))
