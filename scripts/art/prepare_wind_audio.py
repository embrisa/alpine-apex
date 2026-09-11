"""Preserve the supplied wind master and build a reusable, levelled stereo loop."""
from array import array
from pathlib import Path
import argparse
import hashlib
import json
import math
import shutil
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "art_source/audio/wind/wind_forest_01.wav"
RUNTIME = ROOT / "assets/audio/ambience/wind/wind_forest_01.ogg"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=MASTER)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg") or str(
        ROOT / ".tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"))
    args = parser.parse_args()
    source = args.source.resolve()
    MASTER.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    if MASTER.exists() and digest(MASTER) != digest(source):
        raise SystemExit("A different master already exists; choose a new numbered asset.")
    if source != MASTER.resolve():
        shutil.copy2(source, MASTER)
    with wave.open(str(MASTER)) as wav:
        channels, width, rate, frames = wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getnframes()
        if (channels, width) != (2, 2):
            raise SystemExit("This preparation expects the supplied stereo 16-bit WAV.")
        pcm = array("h", wav.readframes(frames))
    peak = max(abs(value) for value in pcm) / 32768.0
    rms = math.sqrt(sum(float(value) ** 2 for value in pcm) / len(pcm)) / 32768.0
    gain_db = -6.0 - 20.0 * math.log10(peak)
    gain = 10.0 ** (gain_db / 20.0) / 32768.0
    samples = array("f", (value * gain for value in pcm))
    # Preserve the full first pass. Tail overlaps the first 250 ms; later loops
    # resume at 250 ms, immediately after the head used by the overlap.
    overlap = round(rate * 0.25)
    for frame in range(overlap):
        weight = 0.5 - 0.5 * math.cos(math.pi * frame / (overlap - 1))
        for channel in range(channels):
            tail = (frames - overlap + frame) * channels + channel
            head = frame * channels + channel
            samples[tail] = samples[tail] * (1.0 - weight) + samples[head] * weight
    with tempfile.TemporaryDirectory(prefix="alpine-wind-") as temporary:
        raw = Path(temporary) / "wind.f32"
        with raw.open("wb") as output:
            samples.tofile(output)
        subprocess.run([args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                        "-f", "f32le", "-ar", str(rate), "-ac", str(channels), "-i", str(raw),
                        "-c:a", "libvorbis", "-q:a", "7", "-threads", "2",
                        "-metadata", "title=Forest wind 01", str(RUNTIME)], check=True)
    manifest = {
        "id": "wind_forest_01", "title": "Forest wind 01", "original_filename": "forest_wind.wav",
        "provenance": "Supplied by the user from Downloads; retain the lossless master for future reuse.",
        "master": str(MASTER.relative_to(ROOT)).replace("\\", "/"), "master_sha256": digest(MASTER),
        "runtime": str(RUNTIME.relative_to(ROOT)).replace("\\", "/"), "runtime_sha256": digest(RUNTIME),
        "channels": channels, "sample_rate": rate, "duration_seconds": frames / rate,
        "source_peak_dbfs": 20.0 * math.log10(peak), "source_rms_dbfs": 20.0 * math.log10(rms),
        "constant_gain_db": gain_db, "target_peak_dbfs": -6.0,
        "loop_offset_seconds": 0.25, "seam_overlap_seconds": 0.25,
        "encoding": "Stereo Vorbis quality 7, original 48 kHz; full duration; no dynamic compression or EQ",
        "loading_volume_db": -12.0, "master_bytes": MASTER.stat().st_size, "runtime_bytes": RUNTIME.stat().st_size,
    }
    (MASTER.parent / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    descriptor = Path(str(RUNTIME) + ".import")
    if descriptor.exists():
        text = descriptor.read_text(encoding="utf-8")
        lines = ["loop=true" if line.startswith("loop=") else
                 "loop_offset=0.25" if line.startswith("loop_offset=") else line
                 for line in text.splitlines()]
        descriptor.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
