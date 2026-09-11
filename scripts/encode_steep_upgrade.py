"""Encode native A/B frames with the local FFmpeg runtime; no replacement imagery.

Use --resume to retain current individual clips and rebuild corrected overviews.
"""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "artifacts/steep_animation_physics_upgrade"


SCENARIOS = [row['scenario'] for row in json.loads((EVIDENCE/'after_visual/results.json').read_text())['cases']]
SUPPLEMENTAL = EVIDENCE / 'after_visual_supplemental/results.json'
if SUPPLEMENTAL.exists():
    for row in json.loads(SUPPLEMENTAL.read_text())['cases']:
        if row['scenario'] not in SCENARIOS:
            SCENARIOS.append(row['scenario'])



def encode():
    executable = str(ROOT / ".tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe")
    output = EVIDENCE / "clips"
    output.mkdir(exist_ok=True)
    records = []
    for view in ("chase", "side", "front"):
        filenames = []
        for scenario in SCENARIOS:
            suffix = ''
            if scenario == 'near_landing_override' and (EVIDENCE/'after_visual_handover/results.json').exists():
                suffix = '_handover'
            elif (EVIDENCE/f'after_visual_supplemental/{scenario}_{view}').is_dir():
                suffix = '_supplemental'
            folders = [EVIDENCE / f"{variant}_visual{suffix}/{scenario}_{view}" for variant in ("before", "after")]
            counts = [len(list(folder.glob("*.jpg"))) for folder in folders]
            if not all(counts):
                raise ValueError(f"Missing captures for {scenario}/{view}: {counts}")
            # Exhaustion/crash may occur at different physical times. Compare the
            # shared prefix and report each duration instead of inventing frames.
            matched = min(counts)
            for folder in folders:
                if any(not (folder / f"{i:04d}.jpg").exists() for i in range(matched)):
                    raise ValueError(f"Missing frame in {folder}")
            target = output / f"{scenario}_{view}.mp4"
            args = [executable, "-hide_banner", "-loglevel", "error", "-y", "-filter_complex_threads", "1"]
            for folder in folders:
                args += ["-threads", "1", "-framerate", "30", "-i", str(folder / "%04d.jpg")]
            args += ["-filter_complex", "[0:v][1:v]hstack=inputs=2[v]", "-map", "[v]",
                     "-c:v", "libx264", "-threads", "2", "-preset", "fast", "-crf", "20",
                     "-frames:v", str(matched), "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(target)]
            newest_source = max(p.stat().st_mtime for folder in folders for p in folder.glob('*.jpg'))
            if '--resume' not in sys.argv or not target.exists() or target.stat().st_mtime < newest_source:
                subprocess.run(args, check=True)
            filenames.append(target.name)
            records.append({"case": scenario, "view": view, "frames": matched, "source_frames":counts,
                            "seconds": matched / 30, "path": str(target), "pixels": [1920, 720],
                            "source_folders": [str(folder) for folder in folders]})
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
        # Slow-motion view retains every native frame at half playback speed.
        slow = output / f"comparison_{view}_slow.mp4"
        subprocess.run([executable,"-v","error","-y","-threads","1","-i",str(overview),"-vf","setpts=2*PTS","-an","-c:v","libx264","-threads","2","-preset","veryfast","-crf","20","-pix_fmt","yuv420p",str(slow)],check=True)
        print(overview,flush=True)
    crash_folders = [EVIDENCE/f'{v}_visual_supplemental/exhaustion_crash_crash' for v in ('before','after')]
    if all(folder.is_dir() for folder in crash_folders):
        # Native Jolt captures await drawing between steps. Their wall-clock
        # intervals vary, so this is a sampled inspection sequence, not real-time
        # evidence. Show the 60 captured poses at a readable 30 fps.
        crash = output/'exhaustion_crash_follow_sampled.mp4'
        args = [executable,'-v','error','-y','-filter_complex_threads','1']
        for folder in crash_folders: args += ['-threads','1','-framerate','30','-i',str(folder/'%04d.jpg')]
        subprocess.run(args+['-filter_complex','[0:v][1:v]hstack=inputs=2[v]','-map','[v]','-c:v','libx264','-threads','2','-preset','veryfast','-crf','20','-pix_fmt','yuv420p',str(crash)],check=True)
        subprocess.run([executable,'-v','error','-threads','1','-i',str(crash),'-f','null','-'],check=True)
    (output / "manifest.json").write_text(json.dumps(records, indent=2), encoding="utf-8")


if __name__ == "__main__":
    encode()
