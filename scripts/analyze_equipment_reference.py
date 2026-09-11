"""Measure a user-provided metal reference; no reference PCM enters the game."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument("reference", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
ffmpeg = root / ".tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"
data = subprocess.run([str(ffmpeg), "-v", "error", "-i", str(args.reference), "-f", "f32le", "-ac", "1", "-ar", "48000", "pipe:1"], check=True, stdout=subprocess.PIPE).stdout
x = np.frombuffer(data, dtype="<f4").astype(float)
rate = 48000
size, hop = 2048, 240
windows = np.lib.stride_tricks.sliding_window_view(x, size)[::hop]
rms = np.sqrt(np.mean(windows**2, axis=1))
active = rms > max(rms.max() * .06, .0001)
spectra = np.abs(np.fft.rfft(windows[active] * np.hanning(size)))**2
power = np.mean(spectra, axis=0)
hz = np.fft.rfftfreq(size, 1/rate)
peaks = np.flatnonzero((power[1:-1] > power[:-2]) & (power[1:-1] > power[2:])) + 1
selected = []
for i in sorted(peaks, key=lambda i: power[i], reverse=True):
    if hz[i] < 700 or hz[i] > 16000 or any(abs(hz[i]-hz[j]) < 220 for j in selected):
        continue
    selected.append(int(i))
    if len(selected) == 14:
        break
bands = {}
for lo, hi in [(0,700),(700,2000),(2000,4000),(4000,8000),(8000,12000),(12000,20000)]:
    bands[f"{lo}-{hi}"] = round(float(power[(hz>=lo)&(hz<hi)].sum()/power.sum()), 4)
onsets = []
for i in range(1, len(rms)-1):
    if rms[i]>rms[i-1] and rms[i]>=rms[i+1] and rms[i]>rms.max()*.12:
        at = (i*hop+size/2)/rate
        if not onsets or at-onsets[-1][0]>.035:
            onsets.append([round(at, 4), float(rms[i])])
        elif rms[i]>onsets[-1][1]:
            onsets[-1] = [round(at,4),float(rms[i])]
result = {"reference":str(args.reference),"sha256":hashlib.sha256(args.reference.read_bytes()).hexdigest(),
          "duration_seconds":len(x)/rate,"analysis_rate":rate,"active_spectral_centroid_hz":round(float((hz*power).sum()/power.sum()),1),
          "band_energy_fractions":bands,"strong_peaks_hz_relative_amplitude":[[round(float(hz[i]),1),round(float(np.sqrt(power[i]/power.max())),3)] for i in selected],
          "energy_peaks_seconds":onsets,"note":"Spectral/onset measurements guide procedural timbre; no reference samples are played by the DSP."}
out = root / "artifacts/natural_audio/reference_analysis.json"
out.write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps({k:v for k,v in result.items() if k!="energy_peaks_seconds"},indent=2))
print("First onset spacings (ms):",np.round(np.diff([p[0] for p in onsets])[:40]*1000,1).tolist())
