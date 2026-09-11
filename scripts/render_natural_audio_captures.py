"""Encode the already captured frames and device PCM after performance runs."""
import json
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FFMPEG = ROOT / ".tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"

for folder, manifest, name in [
    (ROOT / "artifacts/natural_audio/rendered", "report.json", "equipment_impacts"),
    (ROOT / "artifacts/sfx/capture", "frames.json", "skiing_crash"),
]:
    data = json.loads((folder / manifest).read_text(encoding="utf-8-sig"))
    frames = data["frames"] if isinstance(data, dict) else data
    with wave.open(str(folder / (name + ".wav")), "rb") as recording:
        duration = recording.getnframes() / recording.getframerate()
    # Hold the first frame from PCM time zero; subsequent frames retain capture times.
    lines = ["ffconcat version 1.0"]
    for i, frame in enumerate(frames):
        start = float(frame["time"]) if i else 0.0
        end = float(frames[i + 1]["time"]) if i + 1 < len(frames) else duration
        lines += [f"file '{frame['file']}'", f"duration {max(.001, end - start):.6f}"]
    lines.append(f"file '{frames[-1]['file']}'")
    concat = folder / (name + ".ffconcat")
    concat.write_text("\n".join(lines) + "\n", encoding="utf-8")
    output = folder / (name + ".mp4")
    with (folder / (name + "_encode.log")).open("w", encoding="utf-8") as log:
        subprocess.run([str(FFMPEG), "-hide_banner", "-y", "-f", "concat", "-safe", "0", "-i", str(concat),
                        "-i", str(folder / (name + ".wav")), "-c:v", "libx264", "-threads", "4",
                        "-preset", "fast", "-crf", "21", "-pix_fmt", "yuv420p", "-c:a", "aac",
                        "-b:a", "192k", "-t", str(duration), "-movflags", "+faststart", str(output)],
                       stdout=log, stderr=log, check=True)
    print(f"{output}: {duration:.3f} seconds, {output.stat().st_size} bytes")
