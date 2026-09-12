"""Summarize native crystal captures and matched bounded timings, without pass inflation."""
from pathlib import Path
import json
import argparse
import numpy as np
from PIL import Image, ImageDraw


def components(mask):
    remaining = set(map(tuple, np.argwhere(mask)))
    areas = []
    while remaining:
        pending = [remaining.pop()]
        area = 0
        while pending:
            y, x = pending.pop()
            area += 1
            for p in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
                if p in remaining:
                    remaining.remove(p)
                    pending.append(p)
        areas.append(area)
    return sorted(areas)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, nargs="?", default=Path("artifacts/snow_crystal_shape"))
    args = parser.parse_args()
    visual = args.root / "visual"
    # Fixed all-snow crop in the matched near-ground view; exclude sky/rocks.
    crop = (0, 200, 1800, 2000)
    off = np.array(Image.open(visual / "sun_layers_off.png").convert("RGB").crop(crop)).astype(np.int16)
    report = {"scope": "fixed native ground crop; 8-bit display-space diagnostic, not a physical material metric", "crop": crop, "threshold": "mean RGB increase > 12/255 over crystal-off", "visual": {}}
    panels = Image.new("RGB", (1800, 950), "#17202a")
    draw = ImageDraw.Draw(panels)
    for index, mode in enumerate(("before", "after")):
        picture = Image.open(visual / f"sun_layers_{mode}.png").convert("RGB").crop(crop)
        delta = np.array(picture).astype(np.int16) - off
        mask = delta.mean(axis=2) > 12
        areas = components(mask)
        report["visual"][mode] = {"bright_pixels": int(mask.sum()), "components": len(areas), "largest_component_pixels": max(areas, default=0), "components_at_least_64_pixels": sum(a >= 64 for a in areas)}
        panels.paste(picture.resize((900, 900)), (index * 900, 50))
        draw.text((index * 900 + 20, 18), "BEFORE: round ground highlights" if mode == "before" else "AFTER: compact faceted sparkles", fill="white")
    panels.save(args.root / "comparison.png")
    timing_path = args.root / "timing" / "report.json"
    if timing_path.exists():
        timing = json.loads(timing_path.read_text())
        if (timing_path.parent / "INVALIDATED_LAST_PAIR.md").exists():
            timing["samples"] = timing["samples"][:4]
            report["excluded"] = "Original final pair: minimized window, stale renderer queries. See timing/INVALIDATED_LAST_PAIR.md."
            repeat_path = args.root / "timing_repeat" / "report.json"
            if repeat_path.exists():
                repeat = json.loads(repeat_path.read_text())
                changed = [p for p, digest in timing["sources"].items() if p != "res://tests/snow_crystal_shape_playtest.gd" and repeat["sources"].get(p) != digest]
                report["repeat_source_changes"] = changed
                timing["failures"] += repeat["failures"]
                if changed:
                    timing["failures"].append("Comparison production sources changed between original and repeat")
                timing["samples"] += repeat["samples"]
            else:
                timing["failures"].append("Replacement timing pair pending")
        report["timing_failures"] = timing["failures"]
        report["timing"] = {}
        for mode in ("before", "after"):
            rows = [r for r in timing["samples"] if r["look"] == mode]
            report["timing"][mode] = {}
            for metric in ("frame_ms", "gpu_ms", "render_cpu_ms"):
                values = [{k: v for k, v in r[metric].items() if k != "rendered_fps"} for r in rows]
                report["timing"][mode][metric] = {"trials": values, "mean_of_trial_medians": float(np.mean([v["median"] for v in values])), "trial_median_range": [min(v["median"] for v in values), max(v["median"] for v in values)]}
            report["timing"][mode]["rendered_fps"] = [1000 / r["frame_ms"]["mean"] for r in rows]
        report["timing_scope"] = "1800 fixed solver ticks and frame submissions per trial, uncapped wall-clock rendering; FPS comes only from frame intervals"
        report["timing_trajectories_identical"] = len({r["trajectory_sha256"] for r in timing["samples"]}) == 1
        report["timing_trial_count"] = len(timing["samples"])
    (args.root / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
