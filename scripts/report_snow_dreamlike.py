"""Build the matched rendered gallery and measured acceptance report (Pillow/numpy)."""
from pathlib import Path
import html
import json
import subprocess
import numpy as np
from PIL import Image, ImageOps, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/snow_dreamlike"
REVIEW = OUT / "review"
VIEW = Path("artifacts/pc_environment/snow_views")
FFMPEG = ROOT / ".tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

def summarize(segments, key):
    values = [s[key] for s in segments if "mean" in s[key]]
    count = sum(v["samples"] for v in values)
    if not count:
        return {"available":False}
    return {"samples":count,"weighted_mean":sum(v["mean"]*v["samples"] for v in values)/count,
            "worst_segment_p95":max(v["p95"] for v in values),
            "worst_segment_p99":max(v["p99"] for v in values)}

def memory_gib(samples, key, reducer=max):
    values = [s[key] for s in samples if isinstance(s.get(key),(int,float)) and s[key]>0]
    return reducer(values)/2**30 if values else None

def main():
    REVIEW.mkdir(exist_ok=True)
    before, after = OUT / "before" / VIEW, OUT / "after" / VIEW
    meta_a, meta_b = read(before / "snow_fixtures.json"), read(after / "snow_fixtures.json")
    assert meta_a == meta_b, "Camera/weather/terrain metadata must match exactly"
    rows = []
    metrics = []
    for fixture in meta_a:
        name = fixture["name"]
        a, b = Image.open(before / (name + ".png")).convert("RGB"), Image.open(after / (name + ".png")).convert("RGB")
        aa, bb = np.asarray(a), np.asarray(b)
        metrics.append({"name":name, "mean_abs_rgb_delta":float(np.abs(aa.astype(float)-bb).mean()), "before_all_channels_254_fraction":float(np.all(aa >= 254,axis=2).mean()), "after_all_channels_254_fraction":float(np.all(bb >= 254,axis=2).mean())})
        sheet = Image.new("RGB",(1920,568),"#102030")
        sheet.paste(ImageOps.contain(a,(960,540)),(0,28))
        sheet.paste(ImageOps.contain(b,(960,540)),(960,28))
        draw = ImageDraw.Draw(sheet)
        draw.text((12,8),name+" | BEFORE",fill="white")
        draw.text((972,8),"DREAMLIKE",fill="white")
        sheet.save(REVIEW / (name + ".jpg"),quality=93)
        rows.append(f'<section><h2>{html.escape(name)}</h2><a href="{name}.jpg"><img src="{name}.jpg"></a></section>')
    motions = {side:read(OUT / side / VIEW / "snow_motion.json") for side in ("before","after")}
    assert motions["before"] == motions["after"], "Matched motion must execute identical simulation"
    videos = []
    for clip in motions["after"]["clips"]:
        label = clip["clip"]
        players = []
        for side in ("before","after"):
            dest = REVIEW / f"{side}_{label}.mp4"
            if not dest.exists():
                subprocess.run([str(FFMPEG),"-hide_banner","-loglevel","error","-y","-framerate","30","-i",str(OUT/side/VIEW/label/"%03d.jpg"),"-c:v","libx264","-threads","2","-preset","fast","-crf","18","-pix_fmt","yuv420p",str(dest)],check=True)
            players.append(f'<div>{side}<video controls loop muted preload="none" src="{dest.name}"></video></div>')
        videos.append(f'<section><h2>{label}</h2><div class="pair">'+"".join(players)+"</div></section>")
    timings = []
    for weather in ("clear","snowfall"):
        for side in ("before","after"):
            folder = OUT/side/"artifacts/pc_environment"/("snow_timing_"+weather)
            if not (folder/"terrain_timing.json").exists(): continue
            data, system = read(folder/"terrain_timing.json"),read(folder/"system.json")
            assert not data["changed_sources"], "Source changed during measurement"
            assert not system["changed_sources"], "Complete runtime source changed during measurement"
            samples = system["samples"]
            timings.append({"side":side,"weather":weather,"scope":data["scope"],"pixels":data["actual_pixels"],"display":data["display"],"source_stable":not data["changed_sources"],"height_sha256":data["height_sha256"],"obstacle_sha256":data["obstacle_sha256"],"gpu_video_peak_gib":data["peak_video_bytes"]/2**30,"process_private_peak_gib":memory_gib(samples,"private_bytes"),"process_working_set_peak_gib":memory_gib(samples,"working_set_bytes"),"system_free_min_gib":memory_gib(samples,"system_free_bytes",min),"unavailable_process_memory_samples":sum(s.get("private_bytes") is None for s in samples),"wow_samples":sum(s["wow_running"] for s in samples),"total_samples":len(samples),"other_godot_samples":sum(bool(s["other_godot"]) for s in samples),"segments":data["segments"]})
            timings[-1]["summary"] = {key:summarize(data["segments"],key) for key in ("frame_ms","render_gpu_ms","render_cpu_ms","physics_step_us")}
            timings[-1]["samples_meeting_frame_targets"] = sum(s["frame_ms"]["p95"]<=11.1 and s["frame_ms"]["p99"]<=16.7 for s in data["segments"])
    report = {"matched_stills":len(metrics),"matched_motion_clips":len(motions["after"]["clips"]),"motion":motions["after"],"image_metrics":metrics,"image_metric_scope":"Whole-frame SDR readback, including sky; not snow segmentation or HDR clipping measurement.","performance":timings}
    logs = ("graphics_suite.log","golden_suite.log","snow_response_suite.log","pc_graphics_suite.log")
    report["automated"] = {}
    for name in logs:
        lines = (OUT/name).read_text(errors="replace").splitlines()
        report["automated"][name] = {"passed":sum(line.startswith("PASS:") for line in lines), "errors":[line for line in lines if line.startswith(("FAIL:","ERROR:","SCRIPT ERROR:"))]}
        assert not report["automated"][name]["errors"], name
    report["layer_controls"] = read(OUT/"materials/acceptance.json")
    assert report["layer_controls"]["passed"]
    report["runtime_differences"] = read(OUT/"comparison_sources.json")["runtime_differences"]
    report["all_traversal_samples_crash_free"] = all(not segment["crash"] for run in timings for segment in run["segments"])
    assert len(timings)==4, "All four paired timing runs are required"
    for weather in ("clear","snowfall"):
        pair = [run for run in timings if run["weather"]==weather]
        assert pair[0]["height_sha256"]==pair[1]["height_sha256"] and pair[0]["obstacle_sha256"]==pair[1]["obstacle_sha256"]
        signature = lambda run: [(s["face"],s["section_m"],s["start_position"],s["seconds"],s["crash"]) for s in run["segments"]]
        assert signature(pair[0])==signature(pair[1]), "Traversal fixtures differ"
    (OUT/"report.json").write_text(json.dumps(report,indent=2))
    (REVIEW/"index.html").write_text('<!doctype html><meta charset="utf-8"><title>Dreamlike snow review</title><style>body{background:#09121b;color:#eaf3fa;font:16px system-ui;margin:24px auto;max-width:1600px}h1{font-size:32px}h2{font-size:18px}section{margin:32px 0}img,video{width:100%}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}p{max-width:850px;line-height:1.6}</style><h1>Dreamlike snow — matched review</h1><p>v13 / 849205174. Identical cameras, weather, sunlight and terrain. Stills render at 3840×2160; review motion is 30 FPS from fixed 120 Hz simulation / 60 Hz presentation. Screenshots and encoded videos are visual evidence, not performance measurements.</p>'+"".join(videos+rows),encoding="utf-8")
    print(json.dumps({"stills":len(metrics),"clips":len(motions["after"]["clips"]),"timing_runs":len(timings)}))

if __name__ == "__main__": main()
