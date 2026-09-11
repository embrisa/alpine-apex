"""Encode the real rendered A/B frames; never generate replacement imagery.

Install the small standalone encoder into the ignored evidence directory:
python -m pip install --target artifacts/skier_refinement_v16/media_runtime imageio-ffmpeg
"""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "artifacts/skier_refinement_v16"
sys.path.insert(0, str(EVIDENCE / "media_runtime"))
import imageio_ffmpeg

SCENARIOS = ["left_turn", "right_turn", "prepared_hop", "large_jump",
             "small_landing", "medium_landing", "large_landing", "tree_glance", "rock_glance"]


def encode():
    executable = imageio_ffmpeg.get_ffmpeg_exe()
    output = EVIDENCE / "clips"
    output.mkdir(exist_ok=True)
    records = []
    for view in ("chase", "side", "front"):
        filenames = []
        for scenario in SCENARIOS:
            folders = [EVIDENCE / f"{variant}_visual/{scenario}_{view}" for variant in ("before", "after")]
            counts = [len(list(folder.glob("*.jpg"))) for folder in folders]
            if counts[0] != counts[1] or not counts[0]:
                raise ValueError(f"Unmatched frame counts for {scenario}/{view}: {counts}")
            for folder in folders:
                if any(not (folder / f"{i:04d}.jpg").exists() for i in range(counts[0])):
                    raise ValueError(f"Missing frame in {folder}")
            target = output / f"{scenario}_{view}.mp4"
            args = [executable, "-hide_banner", "-loglevel", "error", "-y", "-filter_complex_threads", "1"]
            for folder in folders:
                args += ["-threads", "1", "-framerate", "30", "-i", str(folder / "%04d.jpg")]
            args += ["-filter_complex", "[0:v][1:v]hstack=inputs=2[v]", "-map", "[v]",
                     "-c:v", "libx264", "-threads", "2", "-preset", "fast", "-crf", "20",
                     "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(target)]
            subprocess.run(args, check=True)
            filenames.append(target.name)
            records.append({"case": scenario, "view": view, "frames": counts[0],
                            "seconds": counts[0] / 30, "path": str(target), "pixels": [1920, 720]})
        concat = output / f"{view}_inputs.txt"
        concat.write_text("".join(f"file '{name}'\n" for name in filenames), encoding="utf-8")
        overview = output / f"comparison_{view}.mp4"
        subprocess.run([executable, "-hide_banner", "-loglevel", "error", "-y", "-f", "concat",
                        "-safe", "1", "-i", str(concat), "-c", "copy", "-movflags", "+faststart",
                        str(overview)], check=True)
        # Decode the complete overview, so a successful container write alone
        # is not mistaken for a valid playable clip.
        subprocess.run([executable, "-hide_banner", "-loglevel", "error", "-threads", "1",
                        "-i", str(overview), "-f", "null", "-"], check=True)
        print(overview)
    (output / "manifest.json").write_text(json.dumps(records, indent=2), encoding="utf-8")


if __name__ == "__main__":
    encode()
