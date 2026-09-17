"""Audit existing benchmark receipts; never launch, pool, or repair trials."""

import argparse
import hashlib
import json
import math
from collections import defaultdict
from datetime import datetime
from itertools import pairwise
from pathlib import Path
from statistics import mean, median


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def extent(values):
    return (
        {"min": min(values), "median": median(values), "max": max(values)}
        if values
        else None
    )


def validity(data, system, repetitions):
    errors = list(data.get("failures", []))
    if system.get("schema") not in (None, 1, 2):
        errors.append("unsupported system receipt schema")
    if system.get("exit_code") != 0:
        errors.append("process failed")
    if system.get("schema") == 2:
        errors.extend(metadata_errors(system))
    else:
        # Historical receipts retain their recorded contract; no files are
        # rehashed here and old hash fields are never invented for new runs.
        if system.get("changed_sources") != [] or system.get("source_sha256_before") != system.get("source_sha256_after"):
            errors.append("source drift or missing source receipt")
        if not system.get("source_sha256_before"):
            errors.append("empty source identity")
        if not system.get("engine_sha256"):
            errors.append("missing engine identity")
    for key in [
        "identity",
        "trace_sha256",
        "camera",
        "graphics_profile",
        "renderer",
        "rendering_driver",
    ]:
        if not data.get(key):
            errors.append("missing " + key)
    if data.get("unranked") is not True:
        errors.append("ranked/personal record write eligibility")
    if len(data.get("rows", [])) != repetitions:
        errors.append("incomplete repetitions")
    if (
        data.get("capture_overhead_included") is not False
        or data.get("performance_evidence") is False
    ):
        errors.append("capture/diagnostic overhead")
    if data.get("warmup_frames") != 240:
        errors.append("warmup mismatch")
    for key in ["physical_cache_hit", "scenery_cache_hit"]:
        if data.get("loading", {}).get(key) is not True:
            errors.append(key + " missing/false")
    display = data.get("display", {})
    fx = display.get("fidelityfx", {})
    if data.get("actual_pixels") != [3840, 2160] or display.get(
        "internal_pixels_from_viewport_scale"
    ) != [2880, 1620]:
        errors.append("pixel mismatch")
    if (
        data.get("graphics_preset") != 7
        or data.get("sdfgi") is not False
        or fx.get("frame_generation_active") is not False
    ):
        errors.append("quality/GI/FG mismatch")
    if not fx.get("active_upscaler_version") or fx.get("error"):
        errors.append("provider unavailable/error")
    for row in data.get("rows", []):
        if (
            row.get("exact_trace") is not True
            or row.get("unfocused_frames") != 0
            or row.get("crash")
        ):
            errors.append(f"run {row.get('run')}: endpoint/focus/crash invalid")
        if (
            row.get("frame_ms", {}).get("count", 0) < 1
            or row.get("gpu_ms", {}).get("mean", 0) <= 0
        ):
            errors.append(f"run {row.get('run')}: missing frame/GPU observations")
        for scope in [
            "frame_ms",
            "gpu_ms",
            "render_cpu_ms",
            "draw_calls",
            "submitted_primitives",
            "submitted_objects",
        ]:
            stats = row.get(scope, {})
            if (
                any(
                    not isinstance(v, (int, float)) or not math.isfinite(v) or v < 0
                    for v in stats.values()
                )
                or not stats
            ):
                errors.append(f"run {row.get('run')}: invalid {scope} statistics")
        expected_ticks = 120 * (
            data.get("trial_start_seconds", 0) + data.get("trial_seconds", 0)
        )
        if not expected_ticks or row.get("ticks") != expected_ticks:
            errors.append(f"run {row.get('run')}: incomplete tick window")
        if data.get("scope") == "speed_controlled_stress":
            stress = row.get("stress", {})
            speed = stress.get("speed_kmh", {})
            if (
                any(abs(speed.get(k, 0) - 170) > 0.01 for k in ["min", "max"])
                or stress.get("travelled_m", 0)
                < 170 / 3.6 * data.get("trial_seconds", 0) * 0.9
            ):
                errors.append(f"run {row.get('run')}: invalid stress speed/distance")
    return errors


def metadata_errors(system):
    errors = []
    before, after = [system.get("source_metadata_" + stage) for stage in ("before", "after")]
    for row in (before, after):
        if not isinstance(row, dict) or row.get("schema") != 2 or row.get("method") != "scoped_file_metadata":
            return ["missing scoped metadata receipt"]
        if not row.get("files") or not row.get("engine_files") or not row.get("scope") or not row.get("git", {}).get("commit"):
            return ["incomplete scoped metadata receipt"]
        for metadata in list(row["files"].values()) + list(row["engine_files"].values()):
            if metadata is not None and (not isinstance(metadata, dict) or not isinstance(metadata.get("size"), int) or metadata["size"] < 0 or not isinstance(metadata.get("mtime_ns"), int)):
                return ["malformed file metadata"]
        if any(metadata is None for metadata in row["engine_files"].values()):
            return ["missing engine metadata"]
    if any(before.get(k) != after.get(k) for k in ("files", "engine_files", "scope", "versions", "project_root")):
        errors.append("scoped input drift")
    if system.get("input_error") or system.get("input_changes") != {"method": "scoped_file_metadata", "changed_inputs": [], "stable_inputs": True}:
        errors.append("invalid input comparison")
    return errors


def chronology(directory, row):
    # Godot's profile receipt is parsed and rewritten, producing integral floats.
    run = row["run"]
    if (
        isinstance(run, bool)
        or not isinstance(run, (int, float))
        or not float(run).is_integer()
    ):
        raise ValueError("invalid run number")
    frames = load(directory / f"frame_samples_{int(run)}.json")
    events = load(directory / f"streaming_events_{int(run)}.json")
    timeline = events["frames"]
    if len(timeline) != len(frames["frame_ms"]):
        raise ValueError("chronology/frame sample length mismatch")
    bins = defaultdict(lambda: defaultdict(list))
    for i, frame in enumerate(timeline):
        # Last completed simulation tick, not an exact delayed GPU-frame identity.
        second = min((int(row["ticks"]) - 1) // 120, int(frame[3]) // 120)
        for key in [
            "frame_ms",
            "gpu_ms",
            "render_cpu_ms",
            "draw_calls",
            "submitted_primitives",
            "submitted_objects",
        ]:
            bins[second][key].append(frames[key][i])
    summaries = []
    for second, columns in sorted(bins.items()):
        summaries.append(
            {
                "tick_bin": [second * 120, (second + 1) * 120],
                "means": {k: mean(v) for k, v in columns.items()},
                "frames": len(columns["frame_ms"]),
            }
        )
    by_scope = defaultdict(list)
    for scope, process_frame, begin, end in events["events"]:
        by_scope[scope].append((end - begin) / 1000)
    largest = sorted(events["events"], key=lambda e: e[3] - e[2], reverse=True)[:8]
    worst_frames = []
    for index in sorted(
        range(len(timeline)), key=lambda i: frames["frame_ms"][i], reverse=True
    )[:8]:
        frame = timeline[index]
        overlapping = [
            event
            for event in events["events"]
            if event[2] < frame[2] and event[3] > frame[1]
        ]
        overlapping.sort(key=lambda event: event[3] - event[2], reverse=True)
        worst_frames.append(
            {
                "tick": frame[3],
                "frame_ms": frames["frame_ms"][index],
                "position": frame[4:7],
                "lagged_gpu_ms": frames["gpu_ms"][index],
                "overlapping_cpu_events": overlapping[:8],
            }
        )
    return {
        "bins": summaries,
        "event_max_ms": {k: max(v) for k, v in by_scope.items()},
        "largest_events": largest,
        "worst_frames": worst_frames,
        "gpu_alignment": "GPU values lag these simulation bins; use broad intervals only.",
    }


def telemetry(system, row):
    samples = [
        s
        for s in system.get("samples", [])
        if row["started_unix_seconds"]
        <= datetime.fromisoformat(s["utc"].replace("Z", "+00:00")).timestamp()
        <= row["ended_unix_seconds"]
    ]
    fields = {
        k: extent([s[k] for s in samples if isinstance(s.get(k), (int, float))])
        for k in ["working_set_bytes", "private_bytes", "system_free_bytes"]
    }
    fields["gpu_dedicated_allocation_bytes"] = extent(
        [s["gpu_memory"]["dedicated_bytes"] for s in samples if s.get("gpu_memory")]
    )
    fields["sample_count"] = len(samples)
    fields["other_engines"] = [
        s["other_godot_processes"] for s in samples if s.get("other_godot_processes")
    ]
    fields["background_cpu_machine_percent_max"] = max(
        (
            sum(p["cpu_machine_percent"] for p in s.get("background_processes", []))
            for s in samples
        ),
        default=None,
    )
    process_peaks = defaultdict(float)
    for sample in samples:
        for process in sample.get("background_processes", []):
            process_peaks[process["name"]] = max(
                process_peaks[process["name"]], process["cpu_machine_percent"]
            )
    fields["background_process_peak_cpu_machine_percent"] = dict(
        sorted(process_peaks.items(), key=lambda pair: pair[1], reverse=True)
    )
    fields["memory_scope"] = (
        "Allocation and process telemetry, not physical VRAM occupancy or GPU utilization."
    )
    return fields


def passes(directory):
    data = load(directory / "gpu_passes.json")
    if data["dropped_frames"] or not data["frames_with_passes"]:
        raise ValueError("missing/overflowed native GPU queries")
    groups = defaultdict(list)
    for frame in data["frames"]:
        groups[frame["trial"]].append(frame)
    samples = defaultdict(list)
    interior_frames = 0
    for frames in groups.values():
        if len(frames) < 9:
            raise ValueError("insufficient interior GPU frames")
        # Exclude delayed boundary frames on both ends, retain source frame IDs.
        for frame in frames[4:-4]:
            interior_frames += 1
            markers = frame["markers"]
            frame_values = defaultdict(float)
            for previous, current in pairwise(markers):
                # The pinned renderer emits RENDER_TIMESTAMP before each pass.
                name = previous[0]
                if name.startswith(("<", ">")):
                    continue
                gpu_ms = (current[1] - previous[1]) / 1e6
                if gpu_ms < 0:
                    raise ValueError("nonmonotonic GPU timestamps")
                frame_values[name] += gpu_ms
            for name, gpu_ms in frame_values.items():
                samples[name].append(gpu_ms)
    return {
        "boundary_frames_trimmed_per_end": 4,
        "intervals": sorted(
            [
                {
                    "name": k,
                    "mean_ms": sum(v) / interior_frames,
                    "max_ms": max(v),
                    "count": len(v),
                    "interior_frames": interior_frames,
                }
                for k, v in samples.items()
            ],
            key=lambda r: r["mean_ms"],
            reverse=True,
        ),
        "scope": "Consecutive timestamp intervals named by the starting marker; repeated names summed per frame, absent intervals counted as zero. No nested totals or exact requesting-tick alignment.",
    }


def audit(entry, root):
    directory = root / entry["path"]
    result = dict(entry)
    try:
        data, system = (
            load(directory / "production.json"),
            load(directory / "system.json"),
        )
        result["errors"] = validity(data, system, entry.get("repetitions", 3))
        result["profile_only"] = bool(data.get("gpu_pass_profiling"))
        result["receipts_sha256"] = {
            n: digest(directory / n) for n in ["production.json", "system.json"]
        }
        first = data["rows"][0]
        result["comparison_identity"] = fingerprint(
            {
                k: data.get(k)
                for k in [
                    "identity",
                    "trace_sha256",
                    "camera",
                    "graphics_profile",
                    "actual_pixels",
                    "renderer",
                    "rendering_driver",
                    "weather",
                    "trial_seconds",
                    "trial_start_seconds",
                    "stress",
                ]
            }
            | {
                "engine": system["source_metadata_before"]["engine_files"] if system.get("schema") == 2 else system["engine_sha256"],
                "sources": system["source_metadata_before"]["files"] if system.get("schema") == 2 else system["source_sha256_before"],
                "display": {
                    k: data["display"].get(k)
                    for k in ["fps_limit", "viewport_scale", "msaa"]
                },
                "provider": data["display"]["fidelityfx"].get(
                    "active_upscaler_version"
                ),
                "grass": first.get("grass", {}).get("enabled"),
                "gravel": first.get("gravel", {}).get("mode"),
                "cold_collision": first.get("cold_collision"),
                "gpu_profiling": data.get("gpu_pass_profiling", False),
            }
        )
        result["settings"] = {
            k: data.get(k)
            for k in [
                "actual_pixels",
                "graphics_preset",
                "display",
                "scope",
                "warmup_frames",
                "trial_seconds",
                "trial_start_seconds",
                "trace_sha256",
                "camera",
                "loading",
            ]
        }
        result["engine"] = {
            k: system.get(k)
            for k in ["engine_path", "engine_sha256", "cpu", "environment"]
        }
        result["source_verification"] = "scoped_file_metadata" if system.get("schema") == 2 else "historical_hash_receipt"
        if system.get("schema") == 2:
            result["engine"]["files"] = system["source_metadata_before"]["engine_files"]
            result["recorded_build"] = {k: system["source_metadata_before"].get(k) for k in ("git", "versions", "scope", "limits")}
        result["rows"] = []
        for row in data["rows"]:
            result["rows"].append(
                {
                    "run": row["run"],
                    "encounter": "first measured encounter in process after stationary warmup"
                    if row["run"] == 1
                    else "warmed re-entry in same process",
                    "statistics": {
                        k: v
                        for k, v in row.items()
                        if k not in ["fsr_begin", "fsr_end", "sections"]
                    },
                    "telemetry": telemetry(system, row),
                    "chronology": chronology(directory, row),
                }
            )
        result["medians_of_run_statistics"] = {
            key: median(row["statistics"][field][stat] for row in result["rows"])
            for key, field, stat in [
                ("fps", "frame_ms", "average_fps"),
                ("frame_ms", "frame_ms", "mean"),
                ("p95_ms", "frame_ms", "p95"),
                ("p99_ms", "frame_ms", "p99"),
                ("max_ms", "frame_ms", "max"),
                ("gpu_ms", "gpu_ms", "mean"),
                ("render_cpu_ms", "render_cpu_ms", "mean"),
                ("draw_calls", "draw_calls", "mean"),
                ("submitted_primitives", "submitted_primitives", "mean"),
            ]
        }
        if data.get("gpu_pass_profiling"):
            result["native_gpu"] = passes(directory)
    except (OSError, ValueError, KeyError, TypeError, IndexError) as error:
        result.setdefault("errors", []).append(f"{type(error).__name__}: {error}")
        if (directory / "production.json").exists():
            try:
                result["available_rejected_production"] = load(
                    directory / "production.json"
                )
            except (ValueError, OSError):
                pass
    result["valid"] = not result["errors"]
    return result


def compare(entries):
    groups = defaultdict(list)
    for entry in entries:
        if entry.get("control_group"):
            groups[entry["control_group"]].append(entry)
    results = {}
    for group, rows in groups.items():
        valid = (
            all(r["valid"] and not r.get("profile_only") for r in rows)
            and len({r.get("comparison_identity") for r in rows}) == 1
            and len(rows) >= 2
        )
        summary = {
            "matched_valid_controls": valid,
            "labels": [r["label"] for r in rows],
        }
        if valid:
            summary["observed_process_median_ranges"] = {}
            for metric in ["frame_ms", "gpu_ms", "p95_ms", "p99_ms"]:
                values = [r["medians_of_run_statistics"][metric] for r in rows]
                summary["observed_process_median_ranges"][metric] = extent(values) | {
                    "spread_percent_of_min": 100 * (max(values) / min(values) - 1)
                }
            summary["within_predeclared_repeatability_gate"] = all(
                v["spread_percent_of_min"] <= (3 if k in ["frame_ms", "gpu_ms"] else 15)
                for k, v in summary["observed_process_median_ranges"].items()
            )
        else:
            summary["within_predeclared_repeatability_gate"] = False
        results[group] = summary
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    manifest = load(args.manifest)
    entries = [audit(entry, root) for entry in manifest["runs"]]
    report = {
        "schema": 1,
        "manifest_sha256": digest(args.manifest),
        "method": manifest.get("method", {}),
        "runs": entries,
        "return_controls": compare(entries),
        "cpu_scope_contract": "Microseconds per recorded invocation. Simulation and animation_tick are fixed ticks; pose/camera/effects are render updates; stream scopes are events. Nested scopes overlap and must not be summed.",
        "percentile_contract": "Each run retains its own percentile; aggregate values are medians of run statistics, never pooled percentiles.",
    }
    Path(args.output).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "runs": len(entries),
                "invalid": [e["label"] for e in entries if not e["valid"]],
                "return_controls": report["return_controls"],
            }
        )
    )


if __name__ == "__main__":
    main()
