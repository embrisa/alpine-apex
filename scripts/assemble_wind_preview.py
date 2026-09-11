"""Assemble timestamped rendered frames and the recorded game mix with ffmpeg."""
import json
import shutil
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/wind"
ffmpeg = shutil.which("ffmpeg") or str(ROOT / ".tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe")
times = json.loads((OUT / "descent_frames.json").read_text())
with wave.open(str(OUT / "descent.wav")) as sound:
    duration = sound.getnframes() / sound.getframerate()
concat = ["ffconcat version 1.0"]
for i, start in enumerate(times):
    end = times[i+1] if i+1<len(times) else duration
    # Hold the first captured image over the short delay before the first readback.
    start = start if i else 0
    concat += [f"file 'descent_frames/{i:04d}.jpg'",f"duration {max(.001,end-start):.6f}"]
concat.append(f"file 'descent_frames/{len(times)-1:04d}.jpg'")
(OUT / "descent.ffconcat").write_text("\n".join(concat)+"\n")
subprocess.run([ffmpeg,"-hide_banner","-loglevel","warning","-y","-safe","0","-f","concat","-i",str(OUT/"descent.ffconcat"),
    "-i",str(OUT/"descent.wav"),"-vf","fps=30","-c:v","libx264","-preset","fast","-crf","23","-threads","2",
    "-pix_fmt","yuv420p","-c:a","aac","-b:a","192k","-shortest","-movflags","+faststart",str(OUT/"descent.mp4")],check=True)
print(f"WIND_PREVIEW frames={len(times)} audio_seconds={duration:.3f} video={OUT/'descent.mp4'}")
