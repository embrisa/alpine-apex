"""Summarize native finish-beam receipts; never infer visual acceptance."""
from __future__ import annotations

import argparse
import json
import statistics
from pathlib import Path


def summarize(report: dict) -> dict:
    groups: dict = {}
    warnings = []
    for sample in report.get("measurements", []):
        key = (sample["view"], sample["settings"]["variant"])
        groups.setdefault(key, []).append(sample)
        if sample.get("unfocused_frames", 0):
            warnings.append(f"{key}: unfocused frames; timing is diagnostic")
        if sample.get("sample_seconds", 0) < 15:
            warnings.append(f"{key}: incomplete 15-second sample")
    comparisons = []
    for view in sorted({key[0] for key in groups}):
        result = {"view": view, "metrics": {}}
        for metric in ("frame_ms", "render_cpu_ms", "gpu_ms"):
            summary = {}
            for variant in ("baseline", "proposed"):
                samples = groups.get((view, variant), [])
                values = [s[metric]["mean"] for s in samples if s[metric].get("available")]
                if not values:
                    warnings.append(f"{view}/{variant}/{metric}: no data")
                    continue
                summary[variant] = {
                    "runs": len(values),
                    "run_means_ms": values,
                    "median_run_mean_ms": statistics.median(values),
                    "stddev_run_means_ms": statistics.stdev(values) if len(values) > 1 else 0,
                    "median_run_p95_ms": statistics.median(s[metric]["p95"] for s in samples if s[metric].get("available")),
                    "median_run_p99_ms": statistics.median(s[metric]["p99"] for s in samples if s[metric].get("available")),
                }
            if "baseline" in summary and "proposed" in summary:
                old = summary["baseline"]["median_run_mean_ms"]
                new = summary["proposed"]["median_run_mean_ms"]
                summary["delta_ms"] = new - old
                summary["delta_percent"] = 100 * (new - old) / old if old else None
                if old and new - old > 1 and new / old > 1.2:
                    warnings.append(f"{view}/{metric}: >20% and >1 ms increase; investigate cost")
            result["metrics"][metric] = summary
        comparisons.append(result)
    views = []
    for capture in report.get("captures", []):
        exposed = [s["height_m"] for s in capture.get("shaft_samples", [])
                   if s["in_frame"] and s["terrain_clear"] and s["inside_far_clip"]]
        views.append({
            "label": capture["label"],
            "variant": capture["variant"],
            "horizontal_distance_m": capture["distance_horizontal_m"],
            "terrain_clear_in_frame_samples_m": exposed,
        })
        if not exposed and capture.get("scenario", {}).get("kind", "").startswith("stationary production"):
            warnings.append(f'{capture["label"]}: no sampled shaft in ordinary camera frame')
    return {
        "engine_failures": report.get("failures", []),
        "coverage_gaps": report.get("coverage_gaps", []),
        "warnings": sorted(set(warnings)),
        "comparisons": comparisons,
        "views": views,
        "scope": "Medians of per-run statistics, never pooled percentiles. Shaft samples are terrain-only geometry; inspect images for fog, occlusion, readability and flicker. FPS limits are advisory.",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    print(json.dumps(summarize(json.loads(args.report.read_text(encoding="utf-8-sig"))), indent=2))
