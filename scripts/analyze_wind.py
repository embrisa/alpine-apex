"""Analyze repeatable wind auditions. Requires NumPy; no audio-device claims."""
import json
import wave
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/wind"

def read(path):
    with wave.open(str(path), "rb") as f:
        assert f.getsampwidth() == 2
        return np.frombuffer(f.readframes(f.getnframes()), dtype="<i2").astype(np.float64).reshape(-1, f.getnchannels()) / 32768, f.getframerate()

def db(value):
    return float(20 * np.log10(max(float(value), 1e-12)))

def analyze(path):
    pcm, rate = read(path)
    mono = pcm.mean(axis=1)
    rms = np.sqrt(np.mean(pcm * pcm))
    n = 4096
    data = mono[: len(mono) // n * n].reshape(-1, n)
    spectra = np.abs(np.fft.rfft(data * np.hanning(n), axis=1)) ** 2
    power = spectra.mean(axis=0)
    hz = np.fft.rfftfreq(n, 1 / rate)
    bands = {f"{lo}-{hi}_hz": float(power[(hz >= lo) & (hz < hi)].sum() / power.sum()) for lo, hi in [(0,35),(35,250),(250,1500),(1500,6000),(6000,rate//2)]}
    return {"file":str(path.relative_to(ROOT)),"sample_rate":rate,"seconds":len(pcm)/rate,
        "peak_dbfs":db(np.abs(pcm).max()),"rms_dbfs":db(rms),"dc":float(pcm.mean()),
        "mono_rms_dbfs":db(np.sqrt(np.mean(mono*mono))),"stereo_correlation":float(np.corrcoef(pcm.T)[0,1]) if pcm.shape[1]==2 else 1,
        "band_power_fractions":bands}

def main():
    original, rate = read(ROOT / "assets/wind.wav")
    original_reference = np.sqrt(np.mean(original * original)) * 10 ** ((-48 + 41 * .45 ** .72) / 20)
    dsp = json.loads((OUT / "offline/dsp.json").read_text())
    reference = dsp["rms_at_0_30_90_150_200_540_kmh"][2]
    result = {"reference_speed_kmh":90,"reference_weather":"still air, upright",
        "original_rms":float(original_reference),"procedural_rms":reference,
        "reference_difference_db":db(reference/original_reference),
        "auditions":[analyze(p) for p in sorted((OUT / "offline").glob("*.wav"))]}
    if (OUT / "descent.wav").exists(): result["game_mix"] = analyze(OUT / "descent.wav")
    (OUT / "audio_analysis.json").write_text(json.dumps(result,indent=2))
    print(json.dumps(result,indent=2))

if __name__ == "__main__": main()
