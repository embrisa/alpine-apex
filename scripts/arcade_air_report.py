"""Build review sheets and a matched movie from arcade_air_playtest captures.

Uses original, unretouched frames. Requires Pillow; --video also uses ffmpeg.
Run video encoding outside performance measurements (or through run_guarded).
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import subprocess

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/arcade_air_v27"
CASES = ["hop", "tilt", "frontflip", "backflip", "double_flip",
         "switch_flip", "spin_flip", "reverse", "landing"]
FONT = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 18)
TITLE = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 24)


def tile(revision, case, view, index, size):
    with Image.open(OUT / revision / f"{case}_{view}" / f"{index:04}.jpg") as frame:
        return frame.convert("RGB").resize(size, Image.Resampling.LANCZOS)


def sheets(revision="after_final", cases=CASES):
    folder = OUT / ("review" if revision == "after" else f"{revision}/review")
    folder.mkdir(exist_ok=True)
    for case in cases:
        for view in ("side", "chase"):
            # Every frame in chronological order, split into three readable pages.
            for page in range(3):
                sheet = Image.new("RGB", (1600, 1300), "#142132")
                draw = ImageDraw.Draw(sheet)
                draw.text((12, 8), f"Model 27 / {case} / {view} / frames {page*30}-{page*30+29}", font=TITLE, fill="white")
                for cell in range(30):
                    index = page*30+cell
                    x, y = (cell % 5)*320, 48+(cell//5)*208
                    sheet.paste(tile(revision, case, view, index, (320, 180)), (x, y))
                    draw.text((x+7, y+180), f"{(index+1)/30:.2f}s / frame {index}", font=FONT, fill="white")
                sheet.save(folder / f"{case}_{view}_{page}.jpg", quality=92)
    print(f"{len(cases)*6} chronological review sheets: {folder}")


def movie(revision="after_final"):
    ffmpeg = ROOT / ".tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"
    output = OUT / ("arcade-air-comparison.mp4" if revision == "after" else "arcade-air-final-comparison.mp4")
    width, height = 1600, 1016
    command = [str(ffmpeg), "-hide_banner", "-loglevel", "error", "-y",
               "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", f"{width}x{height}",
               "-framerate", "30", "-i", "pipe:0", "-an", "-c:v", "libx264", "-threads", "1",
               "-preset", "fast", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(output)]
    with subprocess.Popen(command, stdin=subprocess.PIPE) as encoder:
        for case in CASES:
            for index in range(90):
                canvas = Image.new("RGB", (width, height), "#142132")
                draw = ImageDraw.Draw(canvas)
                draw.text((16, 7), f"{case.replace('_', ' ').title()}   /   {(index+1)/30:.2f}s   /   matched input, v14 seed 849205174", font=TITLE, fill="white")
                for row, capture in enumerate(("before", revision)):
                    y = 46+row*484
                    label = "BEFORE / model 26" if row == 0 else "AFTER / model 27"
                    draw.text((16, y), label+"     chase camera                                      side camera", font=FONT, fill="white")
                    for col, view in enumerate(("chase", "side")):
                        canvas.paste(tile(capture, case, view, index, (800, 450)), (col*800, y+28))
                encoder.stdin.write(canvas.tobytes())
        encoder.stdin.close()
        if encoder.wait() != 0:
            raise RuntimeError("ffmpeg failed")
    decoded = subprocess.run([str(ffmpeg), "-hide_banner", "-loglevel", "error", "-threads", "1",
                              "-i", str(output), "-progress", "pipe:1", "-f", "null", "-"],
                             check=True, capture_output=True, text=True)
    counts = [int(line.split("=", 1)[1]) for line in decoded.stdout.splitlines() if line.startswith("frame=")]
    if not counts or counts[-1] != len(CASES)*90:
        raise RuntimeError(f"Expected {len(CASES)*90} decoded video frames; got {counts}")
    print(f"Decoded all {counts[-1]} video frames successfully")
    print(output)


def summary():
    suites = ["arcade_air_suite", "controller_input_suite", "physics_suite", "runtime_suite",
              "rider_lifecycle_suite", "competitive_suite", "airborne_control_suite", "jump_suite",
              "tuck_contact_suite", "landing_absorption_suite", "rock_terrain_suite",
              "steep_upgrade_suite", "steep_motion_suite", "airborne_pose_suite",
              "skier_animation_suite", "ski_attachment_suite"]
    receipts = []
    for suite in suites:
        directory = ROOT / "artifacts/guarded" / f"air27_{suite}"
        guard = json.loads((directory / "guard.json").read_text(encoding="utf-8-sig"))
        log = (directory / "stdout.log").read_text(encoding="utf-8-sig")
        errors = (directory / "stderr.log").read_text(encoding="utf-8-sig")
        checks = None
        for line in log.splitlines():
            if "_RESULTS " in line and "{" in line:
                try:
                    payload = line.split("_RESULTS ", 1)[1]
                    result = json.loads(payload)
                    if isinstance(result, dict):
                        checks = result.get("checks", checks)
                except json.JSONDecodeError:
                    pass
        receipts.append({"suite": suite, "exit_code": guard["exit_code"], "checks": checks,
                         "started": guard["started"], "finished": guard["finished"],
                         "failures": list(dict.fromkeys(line.removeprefix("FAIL: ") for line in (log+"\n"+errors).splitlines() if line.startswith("FAIL:"))),
                         "guard": str(directory.relative_to(ROOT) / "guard.json")})
    before = json.loads((OUT / "before/results.json").read_text())
    after = json.loads((OUT / "after_final/results.json").read_text())
    turn = json.loads((OUT / "turn_final/results.json").read_text())
    cases = []
    for old, new in zip(before["cases"], after["cases"]):
        assert old["name"] == new["name"] and old["initial"] == new["initial"]
        cases.append({"name": new["name"], "before_peak_pitch_deg": math.degrees(max(abs(t["pitch"]) for t in old["trace"])),
                      "after_peak_pitch_deg": math.degrees(max(abs(t["pitch"]) for t in new["trace"])),
                      "frames_per_view": len(new["trace"]), "landings": new["landings"], "crash": new["crash"]})
    files = set(after["sources"]) | set(turn["sources"]) | {"scripts/core/landing_assist.gd", "scripts/racing/run_replay.gd",
                                   "scripts/main.gd", "scripts/presentation/action_posture.gd"}
    hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sorted(files)}
    posture_comparisons = {}
    for name, path in {"full_motion": "artifacts/steep_motion_gameplay/suite_air_baseline.json",
                       "procedural": "artifacts/skier_animation/animation_results_air_baseline.json"}.items():
        comparison = json.loads((ROOT / path).read_text())
        posture_comparisons[name] = {"fixture": "Current presentation with previous air rates",
                                     "checks": comparison["checks"], "failures": comparison["failures"], "path": path}
    report = {"created_utc": datetime.now(timezone.utc).isoformat(), "physics": 27, "replay": 5,
              "suites": receipts, "focused": json.loads((OUT / "focused.json").read_text()),
              "rendered_cases": cases, "current_source_sha256": hashes,
              "capture_source_drift": [name for name, value in after["sources"].items() if hashes[name] != value],
              "final_turn_capture": {"frames_per_view": len(turn["cases"][0]["trace"]),
                                     "landings": turn["cases"][0]["landings"], "crash": turn["cases"][0]["crash"],
                                     "source_drift": [name for name, value in turn["sources"].items() if hashes[name] != value]},
              "capture_identity": {key: after[key] for key in ["generator", "seed", "height_sha256", "obstacle_sha256", "pixels", "fps", "record_eligible", "engine"]},
              "posture_comparisons": posture_comparisons,
              "controller_acceptance": "Not performed; requires the user's physical controller playtest",
              "performance_acceptance": "Not measured by these captures; native 1280x720 with capture overhead"}
    (OUT / "verification.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (OUT / "suites.json").write_text(json.dumps(receipts, indent=2), encoding="utf-8")
    implementation_path = OUT / "implementation.json"
    implementation = json.loads(implementation_path.read_text())
    for name, values in implementation["files"].items():
        values["candidate_sha256"] = hashes[name]
    implementation["verified_utc"] = report["created_utc"]
    implementation["final_turn_capture"] = "turn_final/results.json"
    implementation["final_flip_capture"] = "after_final/results.json"
    implementation_path.write_text(json.dumps(implementation, indent=2), encoding="utf-8")
    print(json.dumps({"suites": len(receipts), "passing": sum(r["exit_code"] == 0 for r in receipts),
                      "failures": [r for r in receipts if r["exit_code"] != 0],
                      "capture_source_drift": report["capture_source_drift"],
                      "final_turn_source_drift": report["final_turn_capture"]["source_drift"]}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--video", action="store_true")
    parser.add_argument("--summary", action="store_true")
    parser.add_argument("--deliver", action="store_true", help="Build final sheets, matched movie and receipt summary together")
    parser.add_argument("--revision", choices=["after", "after_final", "turn_final"], default="after_final")
    parser.add_argument("--case", choices=CASES+["turn"])
    args = parser.parse_args()
    if (args.video or args.deliver) and args.revision == "turn_final":
        parser.error("The matched movie uses the nine-case after/after_final captures.")
    if args.deliver:
        sheets(args.revision)
        movie(args.revision)
        summary()
    else:
        summary() if args.summary else (movie(args.revision) if args.video else sheets(args.revision, [args.case] if args.case else CASES))
