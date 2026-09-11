"""Summarize guarded measurements without mixing physical, scene and FPS costs."""
import json
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "artifacts/generation_v15"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def distribution(values):
    return dict(mean=mean(values), minimum=min(values), maximum=max(values), samples=len(values))


def comparison(old, new):
    a, b = mean(old), mean(new)
    return dict(v14_s=distribution(old), v15_s=distribution(new), saved_s=a-b, saved_percent=100*(a-b)/a)


def memory(label):
    path = ROOT / "artifacts/guarded" / label / "guard.json"
    if not path.exists():
        return None
    guard = read(path)
    result = {"exit_code": guard["exit_code"], "stop_reason": guard["stop_reason"]}
    for key in ["task_private_bytes", "task_working_set_bytes", "task_gpu_dedicated_bytes"]:
        values = [row[key]/2**30 for row in guard["samples"] if row.get(key) is not None]
        result[key.replace("_bytes", "_peak_gib")] = max(values) if values else None
    result["minimum_system_free_gib"] = min(row["free_bytes"] for row in guard["samples"])/2**30
    return result


old = read(EVIDENCE / "v14_baseline.json")["runs"]
current = read(EVIDENCE / "v15_baseline.json")
new = current["runs"][:3]
assert len(old) == len(new) == 3
assert all(row["cache_hit"] and row["cache_matches"] for row in old + new)
assert all(row["matches_first"] for row in current["runs"])
summary = {"physical_source_sha256": current["physical_source_sha256"], "comparisons": {}, "rendered": {}, "worlds": []}
for name, key in [("cold_generation", "cold_ms")]:
    summary["comparisons"][name] = comparison([row[key]/1000 for row in old], [row[key]/1000 for row in new])
wall_path = EVIDENCE / "v15_cache_wall_baseline.json"
if wall_path.exists():
    wall = read(wall_path)
    assert wall["source"] == current["physical_source_sha256"] and not wall["failed"]
    summary["comparisons"]["physical_cache_full_loader"] = comparison([row["physical_cache_ms"]/1000 for row in old], [row["physical_cache_wall_ms"]/1000 for row in wall["runs"]])
summary["timing_boundaries"] = {"cold_generation":"Generator construction; cache publication measured separately", "physical_cache_full_loader":"Complete Cache.generate call including dependency checks", "rendered_readiness":"Physical loader through the ready rendered frame; scene creation and uploads included", "frame_samples":"Ground-clamped dense scenes and 90 m camera traversal; no active skiing solver"}
summary["archive_reconstruction_s"] = distribution([row["physical_cache_ms"]/1000 for row in new])
summary["standard_stage_mean_ms"] = {key: mean(row["stages"][key] for row in new) for key in new[0]["stages"] if isinstance(new[0]["stages"][key], (int, float))}
summary["standard_determinism"] = [{key: row[key] for key in ["workers", "cold_ms", "cache_matches", "matches_first", "height_sha256", "obstacle_sha256"]} for row in current["runs"]]
for name in ["render_v15_p1", "render_v15_p3", "render_v15_p3_spacing50"]:
    path = EVIDENCE / (name + ".json")
    if not path.exists():
        continue
    data = read(path)
    rows = data["runs"]
    result = {"camera_fixture":data.get("camera_fixture", "obsolete_unclamped"), "readiness": [{key: row.get(key) for key in ["repetition", "time_to_ski_ms", "physical_ms", "scene_ms", "physical_cache", "preparation_cache", "trees", "minerals", "actual_pixels", "internal_pixels"]} for row in rows]}
    for scenario, key in [("static", "dense"), ("camera_traversal", "camera_traversal")]:
        if data.get("camera_fixture") != "ground_clamped_dense48_v2" or not all(row.get("actual_pixels")==[3840,2160] for row in rows):
            continue
        samples = [sample for row in rows for sample in row.get("dense", [])]
        if scenario == "camera_traversal":
            samples = [dict(sample["camera_traversal"], video_memory_bytes=sample.get("video_memory_bytes", 0)) for sample in samples if "camera_traversal" in sample]
        if not samples:
            continue
        result[scenario] = {metric: {percentile: distribution([sample[metric][percentile] for sample in samples]) for percentile in ["mean", "p95", "p99"]} for metric in ["frame_ms", "gpu_ms", "render_cpu_ms"]}
        result[scenario]["video_memory_peak_gib"] = max(sample.get("video_memory_bytes", 0) for sample in samples)/2**30
    summary["rendered"][name] = result
    if name == "render_v15_p1":
        warm = [row for row in rows if row.get("physical_cache") and row.get("preparation_cache")]
        if len(warm) == 3 and all(row.get("actual_pixels")==[3840,2160] for row in warm):
            old_render = read(EVIDENCE / "render_v14_p1.json")["runs"]
            assert len(old_render)==3 and all(row.get("actual_pixels")==[3840,2160] and row["physical_cache"] for row in old_render)
            summary["comparisons"]["cached_rendered_time_to_ski"] = comparison([row["time_to_ski_ms"]/1000 for row in old_render], [row["time_to_ski_ms"]/1000 for row in warm])
            summary["preparation_cache_seconds"] = distribution([row["stages"]["preparation_cache_read"]/1000 for row in warm])
for name in ["standard", "alternate_light", "alternate_rich", "trees", "trees_tight", "minerals", "snow", "landforms", "spacing", "saturation", "extreme", "extreme_tight"]:
    path = EVIDENCE / ("world_" + name + ".json")
    if path.exists():
        row = read(path)
        summary["worlds"].append({key: row.get(key) for key in ["case", "seed", "settings", "cold_or_load_ms", "cache_hit", "population", "failures", "routes", "recipe_warm_ms"]})
summary["guard_memory"] = {label: memory(label) for label in ["v15_4k_v14_render", "v15_4k_standard_render", "v15_final_extreme_render", "v15_final_extreme_tight_render", "v15_final_capacity", "v15_frozen_baseline"]}
(EVIDENCE / "measurement_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps(summary["comparisons"], indent=2))
