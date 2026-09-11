"""Assemble timestamped native frames with the matching captured audio."""
import argparse
import json
import shutil
import subprocess
import wave
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
args = parser.parse_args()
if not args.ffmpeg:
    raise SystemExit("Supply --ffmpeg with an existing ffmpeg executable")
out = Path(__file__).resolve().parents[1] / "artifacts/sfx/capture"
frames = json.loads((out / "frames.json").read_text())
with wave.open(str(out / "skiing_crash.wav"), "rb") as wav:
    duration = wav.getnframes() / wav.getframerate()
lines = []
for i, frame in enumerate(frames):
    end = frames[i+1]["time"] if i+1 < len(frames) else duration
    start = frame["time"] if i else 0
    lines += [f"file '{frame['file']}'", f"duration {max(.001,end-start):.6f}"]
lines.append(f"file '{frames[-1]['file']}'")
(out / "frames.ffconcat").write_text("\n".join(lines) + "\n", encoding="utf-8")
subprocess.run([args.ffmpeg, "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", str(out / "frames.ffconcat"),
    "-i", str(out / "skiing_crash.wav"), "-vf", "scale=1920:1080", "-r", "30", "-c:v", "libx264", "-preset", "fast", "-crf", "21",
    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-t", str(duration), "-movflags", "+faststart", str(out / "skiing_crash.mp4")], check=True)
print(f"SFX_PREVIEW frames={len(frames)} audio_seconds={duration:.3f}")
