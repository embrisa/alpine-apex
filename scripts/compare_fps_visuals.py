"""Build a review artifact from native captures, after all FPS timing has ended."""
from pathlib import Path
import argparse
import json
import math
import subprocess
from PIL import Image, ImageChops, ImageStat, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/fps_optimization"
BEFORE, AFTER = OUT / "visual_before", OUT / "visual_after"
FFMPEG = ROOT / ".tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"

def main():
    global OUT, BEFORE, AFTER
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence-root", type=Path, default=OUT)
    args = parser.parse_args()
    OUT = args.evidence_root.resolve()
    BEFORE, AFTER = OUT / "visual_before", OUT / "visual_after"
    b = json.loads((BEFORE / "visuals.json").read_text())
    a = json.loads((AFTER / "visuals.json").read_text())
    assert b["actual_pixels"] == a["actual_pixels"] == [3840, 2160]
    assert b["camera"] == a["camera"]
    assert b["display"]["preferences"] == a["display"]["preferences"]
    assert b["unranked"] and a["unranked"]
    folder = OUT / "visual_comparison"
    folder.mkdir(exist_ok=True)
    cases = []
    assert len(b["cases"]) == len(a["cases"]) == 16
    source_cases = [(BEFORE, AFTER, bc, ac) for bc, ac in zip(b["cases"], a["cases"])]
    track_before, track_after = OUT / "tracks_before", OUT / "tracks_after"
    assert track_before.exists() == track_after.exists(), "Incomplete close-track pair"
    if track_before.exists():
        tb = json.loads((track_before / "visuals.json").read_text())
        ta = json.loads((track_after / "visuals.json").read_text())
        assert tb["actual_pixels"] == ta["actual_pixels"] == [3840,2160]
        assert tb["camera"] == ta["camera"] and tb["display"]["preferences"] == ta["display"]["preferences"]
        assert tb["unranked"] and ta["unranked"] and len(tb["cases"]) == len(ta["cases"]) == 1
        source_cases.append((track_before,track_after,tb["cases"][0],ta["cases"][0]))
    lines = ["# Matched rendering review", "", "Native 4K stills and moving samples, captured separately from performance timing. Comparison videos show the original on the left and optimized version on the right, each at half resolution. Full-resolution originals remain linked below.", "", "Any FPS visible in the HUD includes capture/readback stalls and is not a performance measurement. Motion advances at a fixed 60 Hz; the videos sample every fourth frame (15 samples per second).", "", "Image error is a diagnostic, not visual acceptance: temporal upscaling, GI and particles can differ between processes.", ""]
    for source_before, source_after, bc, ac in source_cases:
        name = bc["id"]
        assert name == ac["id"]
        assert bc["start"] == ac["start"] and bc["end"] == ac["end"], name + " camera/route mismatch"
        assert bc["sdfgi"] and ac["sdfgi"]
        assert not bc["crash"] and not ac["crash"], name + " interrupted by a crash"
        with Image.open(source_before / (name + "_still.png")) as bi, Image.open(source_after / (name + "_still.png")) as ai:
            left = bi.convert("RGB").resize((960, 540), Image.Resampling.LANCZOS)
            right = ai.convert("RGB").resize((960, 540), Image.Resampling.LANCZOS)
            rms = ImageStat.Stat(ImageChops.difference(left, right)).rms
            error = sum(v * v for v in rms) / 3
            psnr = None if error == 0 else 10 * math.log10(255 * 255 / error)
            sheet = Image.new("RGB", (1920, 570), "#111820")
            sheet.paste(left, (0, 30)); sheet.paste(right, (960, 30))
            draw = ImageDraw.Draw(sheet)
            draw.text((12, 8), name + " / ORIGINAL", fill="white")
            draw.text((972, 8), "OPTIMIZED", fill="white")
            sheet.save(folder / (name + ".jpg"), quality=95)
        lists = []
        counts = []
        for label, source in (("before", source_before), ("after", source_after)):
            frames = sorted(source.glob(name + "_[0-9][0-9][0-9].jpg"))
            assert frames, "No moving samples: " + name
            counts.append(len(frames))
            listing = folder / (name + "_" + label + ".txt")
            listing.write_text("".join("file '" + str(p).replace("\\", "/").replace("'", "'\\''") + "'\nduration 0.066666667\n" for p in frames), encoding="utf-8")
            lists.append(listing)
        assert counts[0] == counts[1] == 30, name + " frame-count mismatch"
        motion_sheet = Image.new("RGB",(1280,4*380),"#111820")
        motion_draw = ImageDraw.Draw(motion_sheet)
        for row_index, frame in enumerate((0,40,80,116)):
            y = row_index*380
            motion_draw.text((12,y+4),f"{name} / {frame/60:.2f}s / ORIGINAL",fill="white")
            motion_draw.text((652,y+4),"OPTIMIZED",fill="white")
            for x, source in ((0,source_before),(640,source_after)):
                with Image.open(source/f"{name}_{frame:03d}.jpg") as frame_image:
                    motion_sheet.paste(frame_image.convert("RGB").resize((640,360),Image.Resampling.LANCZOS),(x,y+20))
        motion_sheet.save(folder/(name+"_motion.jpg"),quality=95)
        video = folder / (name + ".mp4")
        subprocess.run([str(FFMPEG), "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lists[0]), "-f", "concat", "-safe", "0", "-i", str(lists[1]), "-filter_complex", "[0:v]scale=1920:1080[l];[1:v]scale=1920:1080[r];[l][r]hstack=inputs=2[v]", "-map", "[v]", "-r", "15", "-c:v", "libx264", "-threads", "2", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video)], check=True)
        cases.append({"id": name, "psnr_at_960x540_db": psnr, "moving_samples": counts[0], "crash": ac["crash"], "matching_motion": True})
        lines += ["## " + name.replace("_", " "), "", f"[Original 4K still](../{source_before.name}/{name}_still.png) · [Optimized 4K still](../{source_after.name}/{name}_still.png) · [Matched motion]({name}.mp4) · [Sampled frames]({name}_motion.jpg)", "", f"![Original and optimized]({name}.jpg)", ""]
    (folder / "comparison.json").write_text(json.dumps({"cases": cases, "visual_acceptance": "Requires rendered review; numeric differences are diagnostic only."}, indent=2), encoding="utf-8")
    (folder / "review.md").write_text("\n".join(lines), encoding="utf-8")
    print("Compared", len(cases), "native still/motion cases")

if __name__ == "__main__":
    main()
