"""Verify the current bounded high-speed benchmark and publish its compact receipt.

The raw frame samples, process telemetry and guarded logs remain under ignored
artifacts.  This producer publishes a source-hashed, three-repetition scenario
receipt; it deliberately does not describe a whole-route baseline.
"""

import argparse
import hashlib
import json
import math
import re
import statistics
import subprocess
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def stats(values):
    ordered = sorted(values)
    require(bool(ordered), "Missing timing samples")
    require(all(math.isfinite(value) and value >= 0 for value in ordered), "Invalid timing sample")
    return {
        "count": len(ordered),
        "mean": statistics.mean(ordered),
        "p95": ordered[min(len(ordered) - 1, int(len(ordered) * .95))],
        "p99": ordered[min(len(ordered) - 1, int(len(ordered) * .99))],
        "max": ordered[-1],
    }


def verify_stats(actual, expected):
    for key, value in stats(actual).items():
        require(math.isclose(value, expected[key], rel_tol=1e-8, abs_tol=1e-8),
                f"Raw timing disagrees with report: {key}")


def median_summary(rows):
    return {
        "wall_seconds": statistics.median(row["wall_seconds"] for row in rows),
        "frame_ms": {key: statistics.median(row["frame_ms"][key] for row in rows)
                     for key in ("mean", "p95", "p99", "max", "average_fps", "median_fps", "slowest_one_percent_fps")},
        "gpu_ms": {key: statistics.median(row["gpu_ms"][key] for row in rows)
                   for key in ("mean", "p95", "p99", "max")},
        "render_cpu_ms": {key: statistics.median(row["render_cpu_ms"][key] for row in rows)
                          for key in ("mean", "p95", "p99", "max")},
        "draw_calls": {key: statistics.median(row["draw_calls"][key] for row in rows)
                       for key in ("mean", "p95", "p99", "max")},
    }


def interval_telemetry(samples, row):
    selected = [sample for sample in samples if row["started_unix_seconds"] <=
                datetime.fromisoformat(sample["utc"]).timestamp() <= row["ended_unix_seconds"]]
    require(selected, "No system telemetry during measured interval")
    gpu = [sample["gpu_memory"] for sample in selected if sample["gpu_memory"]]
    return {
        "sample_count": len(selected),
        "minimum_system_free_bytes": min(sample["system_free_bytes"] for sample in selected),
        "peak_working_set_bytes": max(sample["working_set_bytes"] for sample in selected),
        "peak_private_bytes": max(sample["private_bytes"] for sample in selected),
        "peak_gpu_dedicated_allocated_bytes": max((sample["dedicated_bytes"] for sample in gpu), default=None),
        "peak_gpu_shared_allocated_bytes": max((sample["shared_bytes"] for sample in gpu), default=None),
        "other_godot_observations": sum(bool(sample["other_godot_processes"]) for sample in selected),
        "wow_observations": sum(sample["wow_running"] for sample in selected),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", default="current-v15-high-speed-170-20260913")
    parser.add_argument("--guard", default="current-v15-high-speed-170")
    parser.add_argument("--trace", default="artifacts/current_high_speed_stress/dense_forest_170.json")
    parser.add_argument("--output", default="docs/CURRENT_V15_BOUNDED_HIGH_SPEED_PERFORMANCE_RESULTS.json")
    args = parser.parse_args()

    folder = ROOT / "artifacts" / "pc_environment" / args.label
    guard_folder = ROOT / "artifacts" / "guarded" / args.guard
    trace_path = ROOT / args.trace
    production = read(folder / "production.json")
    system = read(folder / "system.json")
    guard = read(guard_folder / "guard.json")
    trace = read(trace_path)

    require(guard["exit_code"] == 0 and not guard["stop_reason"] and guard["workload_launched"], "Guard failed")
    require(guard["workload_mode"] == "FpsCritical" and not guard["concurrent"], "Benchmark was not uncontended FpsCritical work")
    require(guard["full_mountain"] and guard["full_mountain_reason"].strip(), "Missing recorded full-mountain coverage reason")
    require("scripts/benchmark_pc.ps1" in guard["arguments"], "Wrong guarded benchmark")
    require(system["exit_code"] == 0 and not system["changed_sources"], "Benchmark failed or sources drifted")
    require(system["source_sha256_before"] == system["source_sha256_after"], "Source snapshots differ")
    for source, expected in system["source_sha256_before"].items():
        require(digest(ROOT / source).lower() == expected.lower(), f"Source drift since measurement: {source}")
    require(digest(Path(system["engine_path"])).lower() == system["engine_sha256"].lower(), "Runtime changed")

    logs = (folder / "stdout.log").read_text(encoding="utf-8") + (folder / "stderr.log").read_text(encoding="utf-8")
    require(not re.search(r"^(ERROR:|SCRIPT ERROR:|FAIL )", logs, re.M), "Engine/test errors")
    require(production["scope"] == "speed_controlled_stress", "Wrong benchmark scope")
    require(production["trial_seconds"] == 15 and production["trial_start_seconds"] == 0 and production["warmup_frames"] == 240,
            "Wrong bounded trial or warmup")
    require(production["identity"] == trace["identity"] and production["trace_sha256"] == digest(trace_path), "Trace identity mismatch")
    require(trace["identity"]["model"] == 35 and trace["identity"]["generator"] == 15 and trace["seed"] == 849205174,
            "Unexpected current source identity")
    require(trace["stress"]["speed_kmh"] == 170 and trace["stress"]["immortal"] and trace["stress"]["collision_policy"] == "query_only",
            "Wrong high-speed control protocol")
    require(production["actual_pixels"] == [3840, 2160] and production["graphics_preset"] == 7, "Wrong pixels or quality preset")
    preferences = production["display"]["preferences"]
    require(preferences["upscaler"] == "auto" and preferences["render_scale"] == .75 and not preferences["frame_generation"],
            "Wrong upscaler or frame generation")
    require(production["display"]["internal_pixels_from_viewport_scale"] == [2880, 1620], "Wrong internal resolution")
    require(production["renderer"] == "forward_plus" and production["rendering_driver"] == "d3d12", "Wrong renderer")
    require(not production["sdfgi"] and production["display"]["fps_limit"] == 0, "Wrong GI or frame cap")
    require(production["unranked"] and not production["capture_overhead_included"], "Wrong record/capture isolation")
    require(not production["failures"] and len(production["rows"]) == 3, "Need three successful repetitions")

    rows = production["rows"]
    for index, row in enumerate(rows, 1):
        require(row["run"] == index and row["exact_trace"] and not row["crash"] and row["ticks"] == 1800,
                "Incomplete or inexact repetition")
        require(row["unfocused_frames"] == 0, "Measured window lost focus")
        require(not row["fsr_begin"]["frame_generation_active"] and not row["fsr_end"]["frame_generation_active"], "Frame generation became active")
        stress = row["stress"]
        require(abs(stress["speed_kmh"]["min"] - 170.0) <= .01 and abs(stress["speed_kmh"]["max"] - 170.0) <= .01,
                "Speed controller drifted")
        require(stress["travelled_m"] >= 170.0 / 3.6 * 15.0 * .9, "Insufficient high-speed distance")
        raw = read(folder / f"frame_samples_{index}.json")
        for raw_key, report_key in (("frame_ms", "frame_ms"), ("gpu_ms", "gpu_ms"),
                                    ("render_cpu_ms", "render_cpu_ms"), ("draw_calls", "draw_calls")):
            verify_stats(raw[raw_key], row[report_key])
            require(len(raw[raw_key]) == len(raw["frame_ms"]), "Timing sample counts disagree")
        ordered = sorted(raw["frame_ms"])
        derived = {
            "average_fps": 1000 / statistics.mean(ordered),
            "median_fps": 1000 / statistics.median(ordered),
            "slowest_one_percent_fps": 1000 / statistics.mean(ordered[-max(1, math.ceil(len(ordered) * .01)):]),
        }
        for key, value in derived.items():
            require(math.isclose(value, row["frame_ms"][key], rel_tol=1e-8), f"Incorrect FPS statistic: {key}")
        row["system"] = interval_telemetry(system["samples"], row)
        require(row["system"]["other_godot_observations"] == 0, "Concurrent Godot workload")
    require(all(rows[index]["ended_unix_seconds"] < rows[index + 1]["started_unix_seconds"] for index in range(2)),
            "Repetitions overlapped")

    evidence_paths = [folder / name for name in ("production.json", "system.json", "stdout.log", "stderr.log")]
    evidence_paths += [guard_folder / "guard.json", trace_path]
    evidence_paths += [folder / f"frame_samples_{index}.json" for index in range(1, 4)]
    receipt = {
        "schema": 1,
        "classification": "current_source_hashed_bounded_speed_controlled_performance_scenario",
        "status": "complete",
        "scenario": "Dense-forest 170 km/h speed-controlled stress",
        "scope": "Three independently warmed 15-second capture-free production render repetitions; not a complete descent",
        "identity": production["identity"],
        "trace": {"path": trace_path.relative_to(ROOT).as_posix(), "sha256": digest(trace_path), "stress": trace["stress"],
                  "start": trace["stress"]["start"], "checkpoints": len(trace["checkpoints"])},
        "display": production["display"],
        "actual_pixels": production["actual_pixels"],
        "graphics_preset": production["graphics_preset"],
        "renderer": production["renderer"],
        "rendering_driver": production["rendering_driver"],
        "weather": production["weather"],
        "camera": production["camera"],
        "rows": rows,
        "medians_of_run_statistics": median_summary(rows),
        "environment": system["environment"],
        "cpu": system["cpu"],
        "installed_ram_bytes": system["installed_ram_bytes"],
        "engine_path": system["engine_path"],
        "engine_sha256": system["engine_sha256"],
        "source_sha256": system["source_sha256_before"],
        "benchmark_started_utc": system["started_utc"],
        "benchmark_ended_utc": system["ended_utc"],
        "acceptance": {
            "automated": "passed: source/trace/endpoint/focus and high-speed-control checks for all three repetitions",
            "rendered": "not_inspected: capture-free measurement intentionally did not create a visual review",
            "performance": "measured: current 4K High dense-forest speed-controlled scenario only; its medians are not whole-route acceptance",
            "human_controller": "not_run: benchmark-only velocity control and synthetic full tuck/no-brake input are not player acceptance",
        },
        "limitations": [
            "The benchmark-only driver holds 170 km/h and prevents collision translation stops while preserving support, animation, observers and collision queries.",
            "One dense-forest start, clear/day weather and one camera setting are sampled; other routes, faces, weather, cameras and ordinary control are unmeasured.",
            "CPU scopes can overlap and must not be summed. Windows GPU allocations and engine memory counters are different measures, not physical VRAM occupancy.",
            "Rendered frame timing excludes capture/readback overhead. Display delivery, input latency, visual quality and human/controller smoothness remain unverified.",
        ],
        "evidence": {
            "files_sha256": {path.relative_to(ROOT).as_posix(): digest(path) for path in evidence_paths},
            "benchmark_arguments": guard["arguments"],
            "guard_limits": guard["limits"],
            "guard_exit_code": guard["exit_code"],
            "guard_wait_seconds": guard["wait_seconds"],
            "guard_wall_seconds": (datetime.fromisoformat(guard["finished"]) - datetime.fromisoformat(guard["started"])).total_seconds(),
            "guard_background_driver_app_errors": guard["background_driver_app_errors"],
            "receipt_command": subprocess.list2cmdline(["python", "tests/report_current_bounded_high_speed.py", "--label", args.label,
                                                          "--guard", args.guard, "--trace", args.trace, "--output", args.output]),
            "receipt_producer_sha256": digest(Path(__file__)),
            "checkout_head_at_receipt": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        },
    }
    output = ROOT / args.output
    output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"output": str(output), "runs": 3, "frame_ms_medians": receipt["medians_of_run_statistics"]["frame_ms"]}, indent=2))


if __name__ == "__main__":
    main()
