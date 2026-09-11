"""Summarize matched production runs; percentiles are medians of per-run values."""
from pathlib import Path
import argparse
import json
import statistics

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/fps_optimization"

def read(label):
    folder = ROOT / "artifacts/pc_environment" / label
    return json.loads((folder / "production.json").read_text()), json.loads((folder / "system.json").read_text(encoding="utf-8-sig"))

def summarize(report, system):
    rows = report["rows"]
    metrics = {key: statistics.median(row["frame_ms"][key] for row in rows)
               for key in ("average_fps", "mean", "p95", "p99", "max", "slowest_one_percent_fps")}
    metrics["gpu_mean_ms"] = statistics.median(row["gpu_ms"]["mean"] for row in rows)
    metrics["render_cpu_mean_ms"] = statistics.median(row["render_cpu_ms"]["mean"] for row in rows)
    scopes = {key: {stat: statistics.median(row["cpu_scopes_us"][key][stat] for row in rows)
                    for stat in ("mean", "p95", "p99", "max")}
              for key in rows[0]["cpu_scopes_us"]}
    samples = system.get("samples", [])
    snow = rows[-1]["snow"]["local_deformation"]
    dispatches = snow["dispatch_frames"]
    # Budgets are lifetime counters, including stationary warmup. The original
    # path submitted the complete history plus two footprints per dispatch.
    uploaded = snow.get("uploaded_bytes", dispatches * rows[-1]["snow"]["track_capacity"] * 32 + dispatches * 64)
    return {"runs":len(rows), "metrics":metrics,"cpu_scopes_us":scopes,
            "individual_runs":[{"run":r["run"],"frame_ms":r["frame_ms"],"gpu_ms":r["gpu_ms"],
                                "draw_calls":r["draw_calls"],"peak_engine_static_bytes":r["peak_engine_static_bytes"],
                                "peak_video_bytes":r["peak_video_bytes"],"forest":r["forest"]} for r in rows],
            "powder_uploads":{"bytes":uploaded,"dispatches":dispatches,
                              "bytes_per_dispatch":uploaded/dispatches,
                              "scope":"Lifetime counters including warmup; original bytes derived from its full-upload layout."},
            "sections":{key:{stat:statistics.median(row["sections"][key][stat] for row in rows)
                             for stat in ("average_fps","p95","p99")}
                        for key in rows[0]["sections"]},
            "peak_private_bytes":max((row["private_bytes"] for row in samples if row.get("private_bytes") is not None),default=None),
            "min_system_free_bytes":min((row["system_free_bytes"] for row in samples if row.get("system_free_bytes") is not None),default=None),
            "peak_gpu_dedicated_allocation_bytes":max((row["gpu_memory"]["dedicated_bytes"] for row in samples if (row.get("gpu_memory") or {}).get("dedicated_bytes") is not None),default=None),
            "other_engine_observed":any(row.get("other_godot_processes") for row in samples),
            "frame_generation_active":all(row["fsr_begin"]["frame_generation_active"] and row["fsr_end"]["frame_generation_active"] for row in rows),
            "generated_frames_during_descents":sum(row["fsr_end"]["generated_frames"]-row["fsr_begin"]["generated_frames"] for row in rows),
            "runtime_sources_changed":system.get("changed_sources", []),
            "all_exact":all(row["exact_trace"] and row["finished"] and not row["crash"] for row in rows),
            "target_met":all(row["frame_ms"]["p95"]<=11.1 and row["frame_ms"]["p99"]<=16.7 for row in rows)}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline-prefix", default="fps_reference")
    parser.add_argument("--candidate-prefix", default="fps_final")
    args = parser.parse_args()
    result = {"aggregation":"Median of per-run statistics; never pooled percentiles.", "comparisons":{}}
    lines = ["# FPS optimization measurements", "", "All runs use the same successful ordinary-input descent, 4K High, FSR 4.1 at 75%, terrain GI on and no frame cap. Loading and captures are excluded. Percentiles below are medians of per-run percentiles.", ""]
    for mode in ("off", "on"):
        try:
            before, bs = read(f"{args.baseline_prefix}_fg_{mode}")
            after, ats = read(f"{args.candidate_prefix}_fg_{mode}")
        except FileNotFoundError:
            continue
        assert before["identity"] == after["identity"], "Physical identity mismatch"
        assert before["trace_sha256"] == after["trace_sha256"], "Input trace mismatch"
        assert before["display"]["preferences"] == after["display"]["preferences"], "Graphics mismatch"
        assert before["camera"] == after["camera"], "Camera mismatch"
        assert before["actual_pixels"] == after["actual_pixels"] == [3840,2160]
        assert before["sdfgi"] and after["sdfgi"]
        assert before["unranked"] and after["unranked"]
        assert not before["capture_overhead_included"] and not after["capture_overhead_included"]
        for report in (before,after):
            assert report["display"]["internal_pixels_from_viewport_scale"] == [2880,1620]
            for row in report["rows"]:
                for status in (row["fsr_begin"],row["fsr_end"]):
                    assert status["engine_integration"] and status["active_upscaler_version"].startswith("4.1.")
                    assert not status["error"]
                    if mode == "off": assert not status["frame_generation_active"]
                assert row["fsr_end"]["upscale_dispatches"] > row["fsr_begin"]["upscale_dispatches"]
                # The two interval boundary frames are excluded by the timer.
                assert abs(row["fsr_end"]["upscale_dispatches"]-row["fsr_begin"]["upscale_dispatches"]-row["frame_ms"]["count"]) <= 3
        assert not bs["changed_sources"] and not ats["changed_sources"], "Sources changed during a measured run"
        assert bs["exit_code"] == ats["exit_code"] == 0
        b, a = summarize(before, bs), summarize(after, ats)
        assert b["all_exact"] and a["all_exact"], "Incomplete or divergent descent"
        comparison = {"baseline":b,"candidate":a,"identity":before["identity"],"preferences":before["display"]["preferences"],
                      "fps_change_percent":100*(a["metrics"]["average_fps"]/b["metrics"]["average_fps"]-1),
                      "p95_reduction_percent":100*(1-a["metrics"]["p95"]/b["metrics"]["p95"])}
        result["comparisons"][mode] = comparison
        lines += [f"## Frame generation requested {mode}", "", f"{b['runs']} baseline / {a['runs']} optimized descents. Underlying rendered frames are measured in both configurations.", ""]
        if mode == "on" and not (b["frame_generation_active"] and a["frame_generation_active"]):
            lines += ["**Frame generation was requested but did not remain active in this production workload. This is not an active-frame-generation performance result.**",
                      f"Generated-frame increments during measured descents: {b['generated_frames_during_descents']} before / {a['generated_frames_during_descents']} after.", ""]
        lines += ["| Metric | Before | After |", "|---|---:|---:|"]
        for key, label in (("average_fps","Rendered FPS"),("p95","p95 frame ms"),("p99","p99 frame ms"),("slowest_one_percent_fps","Slowest 1% FPS"),("gpu_mean_ms","Mean GPU ms")):
            lines.append(f"| {label} | {b['metrics'][key]:.3f} | {a['metrics'][key]:.3f} |")
        lines += ["", "| Descent | Before FPS / p95 / p99 ms | After FPS / p95 / p99 ms |", "|---|---:|---:|"]
        for br, ar in zip(b['individual_runs'], a['individual_runs']):
            def run_text(r):
                m = r['frame_ms']
                return f"{m['average_fps']:.2f} / {m['p95']:.3f} / {m['p99']:.3f}"
            lines.append(f"| {br['run']} | {run_text(br)} | {run_text(ar)} |")
        lines += ["", "Route sections are radial bands, not exclusive biome classifications.", "", "| Section | Before FPS / p95 / p99 ms | After FPS / p95 / p99 ms |", "|---|---:|---:|"]
        for section in ('open','powder','minerals','forest'):
            def section_text(report):
                m = report['sections'][section]
                return f"{m['average_fps']:.2f} / {m['p95']:.3f} / {m['p99']:.3f}"
            lines.append(f"| {section} | {section_text(b)} | {section_text(a)} |")
        lines += ["", "| CPU scope | Before mean µs | After mean µs |", "|---|---:|---:|"]
        for scope in a["cpu_scopes_us"]:
            lines.append(f"| {scope} | {b['cpu_scopes_us'][scope]['mean']:.2f} | {a['cpu_scopes_us'][scope]['mean']:.2f} |")
        lines += ["", f"Powder upload bytes per dispatch: {b['powder_uploads']['bytes_per_dispatch']:.1f} → {a['powder_uploads']['bytes_per_dispatch']:.1f}. These lifetime counters include warmup; the original full-upload volume is calculated from its unchanged buffer layout.",
                  "", "| Memory telemetry | Before MiB | After MiB |", "|---|---:|---:|"]
        for key, label in (("peak_private_bytes","Peak process private memory"),("min_system_free_bytes","Minimum system free RAM"),("peak_gpu_dedicated_allocation_bytes","Peak Windows GPU dedicated allocations")):
            def memory_text(value):
                return "Unavailable" if value is None else f"{value/1048576:.1f}"
            lines.append(f"| {label} | {memory_text(b[key])} | {memory_text(a[key])} |")
        lines += ["", "Windows GPU allocation counters are not a physical VRAM occupancy measurement. Per-descent engine memory and draw-call distributions are retained in summary.json."]
        lines += ["",f"Frame-time target met on every optimized run: **{a['target_met']}**.", ""]
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/"summary.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
    (OUT/"measurements.md").write_text("\n".join(lines),encoding="utf-8")
    print(json.dumps({k:{"fps_change_percent":v["fps_change_percent"],"p95_reduction_percent":v["p95_reduction_percent"]} for k,v in result["comparisons"].items()}))

if __name__ == "__main__": main()
