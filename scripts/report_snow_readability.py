"""Build a portable local before/after gallery from the native snow fixtures."""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
import subprocess

from PIL import Image, ImageChops, ImageStat


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--visual", default="artifacts/snow_readability/visual")
    parser.add_argument("--timing", default="artifacts/snow_readability/timing")
    parser.add_argument("--videos", action="store_true")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    visual = project / args.visual
    report = json.loads((visual / "report.json").read_text())
    pairs: dict[str, dict] = {}
    clips: dict[str, dict] = {}
    metrics = []
    cards = []
    for sample in report["samples"]:
        if "image" in sample:
            pairs.setdefault(sample["name"], {})[sample["look"]] = sample
        if "frames_path" in sample:
            clips.setdefault(sample["name"], {})[sample["look"]] = sample
    for stem in ("shape_isolation", "contact_isolation"):
        if stem + "_off" in pairs and stem + "_on" in pairs:
            pairs[stem] = {"before": pairs[stem + "_off"]["after"], "after": pairs[stem + "_on"]["after"]}
    for name, pair in pairs.items():
        if set(pair) != {"before", "after"}:
            continue
        a = visual / Path(pair["before"]["image"]).name
        b = visual / Path(pair["after"]["image"]).name
        for key in ("camera_position", "camera_basis", "hour", "weather"):
            assert pair["before"][key] == pair["after"][key], f"Unmatched {key}: {name}"
        with Image.open(a) as before, Image.open(b) as after:
            # Diagnostic image statistics only; no automatic claim of readability.
            left = before.convert("RGB")
            right = after.convert("RGB")
            difference = ImageChops.difference(left, right)
            metrics.append({"name": name, "mean_absolute_rgb_difference": ImageStat.Stat(difference).mean,
                            "before_mean_luma": ImageStat.Stat(left.convert("L")).mean[0],
                            "after_mean_luma": ImageStat.Stat(right.convert("L")).mean[0]})
        title = html.escape(name.replace("_", " "))
        labels = ("Treatment off", "Treatment on") if "isolation" in name else ("Before", "After")
        cards.append(f'<article><h2>{title}</h2><div class="pair"><figure><a href="{a.name}"><img loading="lazy" src="{a.name}"></a><figcaption>{labels[0]}</figcaption></figure><figure><a href="{b.name}"><img loading="lazy" src="{b.name}"></a><figcaption>{labels[1]}</figcaption></figure></div></article>')
    encoder = project / ".tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"
    if args.videos and not encoder.exists():
        raise FileNotFoundError(encoder)
    for name, pair in clips.items():
        assert pair["before"]["trajectory_sha256"] == pair["after"]["trajectory_sha256"], f"Unmatched motion: {name}"
        videos = []
        for look in ("before", "after"):
            if look not in pair:
                continue
            folder = visual / Path(pair[look]["frames_path"]).name
            target = visual / f"{name}_{look}.mp4"
            if args.videos:
                subprocess.run([str(encoder), "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30",
                                "-i", str(folder / "%04d.jpg"), "-c:v", "libx264", "-threads", "4", "-crf", "18",
                                "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(target)], check=True)
            if target.exists():
                videos.append(f'<figure><video controls muted loop preload="metadata" src="{target.name}"></video><figcaption>{look.title()}</figcaption></figure>')
        if videos:
            duration = pair["after"]["seconds"]
            ending = " Ends at the same tree impact in both looks." if pair["after"].get("crash") else ""
            cards.append(f'<article><h2>{html.escape(name.replace("_", " "))} — motion</h2><p>{duration:.2f} seconds, identical simulation trajectories.{ending}</p><div class="pair">{"".join(videos)}</div><button onclick="this.previousElementSibling.querySelectorAll(\'video\').forEach(v=>{{v.currentTime=0;v.play()}})">Play both from start</button></article>')
    timings = project / args.timing / "report.json"
    timing_text = "Timing report not present."
    if timings.exists():
        data = json.loads(timings.read_text())
        groups: dict[str, list] = {}
        for sample in data["samples"]:
            if "frame_ms" in sample:
                groups.setdefault(sample["name"] + " / " + sample["look"], []).append(sample)
        timing_rows = []
        for key, rows in sorted(groups.items()):
            def avg(group: str, metric: str) -> str:
                values = [row[group][metric] for row in rows if metric in row.get(group, {})]
                return f"{sum(values)/len(values):.3f}" if values else "unavailable"
            timing_rows.append(f'<tr><td>{html.escape(key)}</td><td>{len(rows)}</td><td>{avg("frame_ms", "mean")}</td><td>{avg("frame_ms", "p95")}</td><td>{avg("frame_ms", "p99")}</td><td>{avg("gpu_ms", "mean")}</td><td>{avg("render_cpu_ms", "mean")}</td></tr>')
        timing_text = '<p>Mean of the per-run statistics below; p95/p99 are not pooled. Short skiing fixtures, frame generation off.</p><table><tr><th>Fixture / look</th><th>Runs</th><th>Frame mean ms</th><th>p95 ms</th><th>p99 ms</th><th>GPU mean ms</th><th>Render CPU mean ms</th></tr>' + "".join(timing_rows) + '</table>'
    summary = {
        "image_pairs": len(metrics), "motion_pairs": len(clips),
        "diagnostic_image_metrics": metrics,
        "visual_failures": report["failures"],
        "shape_preparation": report["snow_shape"],
        "acceptance": "Rendered inspection and human skiing acceptance are separate; image metrics do not grade readability.",
    }
    (visual / "review_metrics.json").write_text(json.dumps(summary, indent=2))
    page = '''<!doctype html><meta charset="utf-8"><title>Alpine Apex — Snow readability</title>
<style>body{background:#172431;color:#e7f0f7;font:16px system-ui;margin:32px}h1{margin-bottom:8px}p{max-width:1000px;color:#b9cddd}article{margin:32px 0}h2{font-size:18px}.pair{display:flex;gap:12px}figure{margin:0;flex:1;min-width:0}img,video{width:100%;border-radius:6px}figcaption{text-align:center;padding:8px}button{background:#c5e3ef;color:#102432;border:0;padding:8px 14px;border-radius:5px;cursor:pointer}table{border-collapse:collapse;font-size:14px}td,th{padding:8px;border-bottom:1px solid #496071;text-align:left}</style>
<h1>Snow readability</h1><p>Frozen original shaders and current shading on the same default v14 mountain. 3840×2160 output, Auto FSR at 75%, frame generation and SDFGI off. Videos are stored at 1920×1080 / 30 fps. Inspect shallow folds, contacts, glare and stability in motion. These are unranked test fixtures; your skiing acceptance remains separate.</p>'''
    page = page.replace("Frozen original shaders and current shading on the same default v14 mountain.",
                        html.escape(report.get("comparison_description", "Frozen original shaders and current shading on the same default v14 mountain.")))
    page = page.replace("Snow readability", html.escape(report.get("title", "Snow readability")))
    page = page.replace("Videos are stored at 1920×1080", "Videos are stored at " + html.escape(report.get("video_resolution", "1920×1080")))
    page += "<h2>Performance</h2>" + timing_text + "".join(cards)
    (visual / "index.html").write_text(page, encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
