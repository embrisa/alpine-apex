"""Make chronological contact sheets and paired videos from the native captures."""
from pathlib import Path
import re
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CAPTURES = ROOT / "artifacts/snow_grounding_v28/visual"
FFMPEG = ROOT / ".tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"
groups = {}
for path in CAPTURES.glob("*.jpg"):
    match = re.fullmatch(r"(.+)_(\d{3})", path.stem)
    if match:
        groups.setdefault(match[1], []).append(path)
font_path = Path("C:/Windows/Fonts/segoeui.ttf")
font = ImageFont.truetype(str(font_path), 20) if font_path.exists() else ImageFont.load_default()
for name, paths in sorted(groups.items()):
    paths.sort()
    indices = sorted({round(i * (len(paths) - 1) / 11) for i in range(12)})
    sheet = Image.new("RGB", (2048, 1008), "#152332")
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 8), name + " - consecutive motion sampled across the full clip", font=font, fill="white")
    for cell, index in enumerate(indices):
        x, y = (cell % 4) * 512, 44 + (cell // 4) * 320
        with Image.open(paths[index]) as frame:
            frame.thumbnail((512, 288))
            sheet.paste(frame, (x, y))
        draw.text((x + 8, y + 290), f"Frame {index:03d} / {index / 30:.2f} s", font=font, fill="white")
    target = CAPTURES / (name + "_timeline.jpg")
    sheet.save(target, quality=94)
    print(target)
if not FFMPEG.exists():
    raise SystemExit("Contact sheets created; the local ffmpeg executable is unavailable.")
for name in sorted(groups):
    if not name.endswith("_before"):
        continue
    after = name.removesuffix("_before") + "_after"
    if after not in groups:
        continue
    target = CAPTURES / (name.removesuffix("_before") + "_comparison.mp4")
    subprocess.run([
        str(FFMPEG), "-hide_banner", "-loglevel", "error", "-y",
        "-framerate", "30", "-i", str(CAPTURES / (name + "_%03d.jpg")),
        "-framerate", "30", "-i", str(CAPTURES / (after + "_%03d.jpg")),
        "-filter_complex", "[0:v]scale=960:540[l];[1:v]scale=960:540[r];[l][r]hstack=inputs=2:shortest=1",
        "-c:v", "libx264", "-threads", "2", "-crf", "20", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", str(target),
    ], check=True)
    print(target)
