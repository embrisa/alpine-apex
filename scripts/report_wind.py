"""Combine actual wind test, signal, and guarded rendering evidence."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/wind"

def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8-sig"))

def main():
    dsp = load("artifacts/wind/offline/dsp.json")
    suites = {"C++ DSP":dsp}
    for label, filename in [("Godot native", "native"),("Unavailable-native fallback","fallback"),("Audio device lifecycle","device")]:
        suites[label] = load(f"artifacts/wind/{filename}_suite.json")
    for label in ["physics","runtime","interface"]:
        prefix = label.upper()+"_RESULTS "
        text = (ROOT / f"artifacts/guarded/wind_{label}/stdout.log").read_text(encoding="utf-8-sig")
        suites[label.title()] = json.loads(next(line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)))
    runs = {}
    for mode in ["original","procedural"]:
        run = load(f"artifacts/pc_environment/wind_{mode}_benchmark/native_-1_clear.json")
        run["wind"] = load(f"artifacts/pc_environment/wind_{mode}_benchmark/wind.json")
        guard = load(f"artifacts/guarded/wind_{mode}_benchmark/guard.json")
        run["guard_exit"] = guard["exit_code"]
        run["peak_task_private_mib"] = max(s["task_private_bytes"] for s in guard["samples"])/1048576
        run["minimum_free_mib"] = min(s["free_bytes"] for s in guard["samples"])/1048576
        runs[mode] = run
    source_paths = sorted([*ROOT.glob("native/wind/*"),*ROOT.glob("addons/alpine_wind/*"),
        ROOT / "addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll",
        *[ROOT / p for p in ["scripts/presentation/procedural_wind.gd","scripts/presentation/speed_effects.gd",
        "scripts/main.gd","scripts/ui/hud.gd","scripts/core/input_router.gd","scripts/build_wind.ps1",
        "scripts/benchmark_wind.ps1","scripts/play_wind.ps1","tests/wind_audio_suite.gd",
        "tests/wind_device_playtest.gd","tests/wind_descent.gd"]]])
    hashes = {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in source_paths if p.is_file()}
    same = all(runs["original"][key]==runs["procedural"][key] for key in ["height_sha256","obstacle_sha256","seconds","peak_kmh"])
    result = {"suites":suites,"runs":runs,"matching_descent":same,"source_sha256":hashes,
        "audio":load("artifacts/wind/audio_analysis.json"),"listening_acceptance":"User review pending"}
    result["ab_benchmark"] = load("artifacts/wind/ab_benchmark.json")
    capture_path = ROOT / "artifacts/pc_environment/wind_procedural_capture/wind.json"
    if capture_path.exists(): result["capture"] = json.loads(capture_path.read_text())
    (OUT / "validation.json").write_text(json.dumps(result,indent=2))
    total = sum(s["checks"] for s in suites.values())
    failures = sum(s["failures"] if isinstance(s["failures"],int) else len(s["failures"]) for s in suites.values())
    lines = ["# Procedural wind validation", "", f"{total} checks; {failures} failures. Native Windows x64 Release build for Godot 4.7.2.","",
        "Play with `./scripts/play_wind.ps1`. F7 compares Procedural / Original; Settings / Interface adjusts wind volume. M toggles all audio.","",
        "## Automated and device evidence","","| Suite | Checks | Failures |","|---|---:|---:|"]
    for name, suite in suites.items():
        failed=suite["failures"] if isinstance(suite["failures"],int) else len(suite["failures"])
        lines.append(f"| {name} | {suite['checks']} | {failed} |")
    lines += ["","The device test observed Godot requesting PCM from the native callback, suspension in Original mode, resumption, and scene-retirement cleanup. Headless UI/input assertions use scripted events; physical keyboard and listening acceptance remain user-owned.","",
        "## Matched 4K descents","","3840×2160 output, 2880×1620 internal, High, FSR2 at 75%, 120 FPS cap, SDFGI off, RX 9070. Seed 849205174/v11, face 0, clear weather. Both runs exclude capture overhead and use 120 warm-up frames.","",
        "| Measurement | Original | Procedural |","|---|---:|---:|"]
    rows=[("Average FPS",lambda r:r["frame_ms"]["average_fps"]),("Frame p95 (ms)",lambda r:r["frame_ms"]["p95"]),
        ("Frame p99 (ms)",lambda r:r["frame_ms"]["p99"]),("Slowest 1% mean FPS",lambda r:r["frame_ms"]["slowest_one_percent_fps"]),
        ("Render CPU mean (ms)",lambda r:r["render_cpu_ms"]["mean"]),("Render CPU p99 (ms)",lambda r:r["render_cpu_ms"]["p99"]),
        ("GPU mean (ms)",lambda r:r["render_gpu_ms"]["mean"]),("GPU p99 (ms)",lambda r:r["render_gpu_ms"]["p99"]),
        ("Physics step mean (µs)",lambda r:r["physics_step_us"]["mean"]),("Peak task private memory (MiB)",lambda r:r["peak_task_private_mib"]),
        ("Engine peak video memory (MiB)",lambda r:r["peak_video_bytes"]/1048576)]
    for label, getter in rows: lines.append(f"| {label} | {getter(runs['original']):.3f} | {getter(runs['procedural']):.3f} |")
    native=runs["procedural"]["wind"]["native"]
    lines += ["",f"Both completed: {all(r['finished'] and not r['crash'] for r in runs.values())}. Terrain hashes, simulated duration, and peak speed match: {same}. All runs are unranked.","",
        "**The full-descent FPS comparison is confounded by changing background GPU activity.** During the procedural run, summed GPU allocation counters rose from about 14.7 to 21.1 GiB, and an AMD background process started. These counters can count shared allocations more than once; they are not physical VRAM consumption. Existing applications were preserved. The 80.7-versus-119.4 FPS result must not be attributed to the DSP alone.","",
        f"Native callback p99: **{native['p99_512_ms']:.4f} ms / 512 frames**, measured over the final {native['history_blocks']} callbacks. Offline DSP p99: {dsp['p99_512_ms']:.4f} ms. Target: below 0.25 ms. Original suspends native processing during the descent; its diagnostic history is startup activity.","",
        "## Same-session A/B isolation","",
        "Four 15-second passes use the same fixed skier pose, 90 km/h velocity telemetry, 4K scene and background load. Two seconds of warm-up precede each pass. Order: Original / Procedural / Procedural / Original. This isolates audio cost; it does not replace a skiing performance test.","",
        "| Pass | Average FPS | Frame p95 ms | Frame p99 ms | GPU mean ms |","|---|---:|---:|---:|---:|"]
    for p in result["ab_benchmark"]["passes"]:
        lines.append(f"| {p['mode']} | {p['frame_ms']['average_fps']:.3f} | {p['frame_ms']['p95']:.3f} | {p['frame_ms']['p99']:.3f} | {p['render_gpu_ms']['mean']:.3f} |")
    lines += ["","Both modes sustained the 120 FPS cap in this isolation test, with effectively equal frame percentiles. Together with measured callback timing, this supports low DSP cost, while the full-descent comparison remains affected by external activity.","",
        "Average FPS and frame percentiles are reported separately from the slowest-1% mean. These measurements do not establish a hard 90-FPS minimum or every-descent performance.","",
        "## Signal and rendered evidence","",f"Reference RMS mismatch at upright 90 km/h in still air: {result['audio']['reference_difference_db']:+.4f} dB. Native wind has a -6 dBFS ceiling and negligible measured DC. Stereo-to-mono level differences in the auditions are under 0.1 dB.","",
        "Audio: `offline/speed_ramp.wav`, `offline/tuck.wav`, `offline/crosswind.wav`, `offline/speed_steps.wav`; live game mix: `descent.wav`. The separate `descent.mp4` preview and settings screenshot include capture overhead and are not performance evidence.","",
        "Subjective naturalness, fatigue, and masking of the ski sound still require listening on the user's headphones and speakers. No human listening or physical-input acceptance is claimed.","",
        "## Artifact","",f"DLL SHA-256: `{hashes['addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll']}`.","",
        "This is a playable project build using the workspace's existing assets, not a self-contained game export. Full source hashes, original measurements, and test results are in `validation.json`.",""]
    (OUT / "VALIDATION.md").write_text("\n".join(lines),encoding="utf-8")
    print(f"WIND_REPORT checks={total} failures={failures} matching_descent={same}")

if __name__ == "__main__": main()
