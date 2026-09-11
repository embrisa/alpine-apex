"""Summarize measured audio evidence and prepare user-controlled WAV auditions.

Run with a Python containing NumPy. This analyzes signals, not listening quality.
"""
import hashlib
import json
import math
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/natural_audio"
AFTER = OUT / "after/offline"
BEFORE = OUT / "baseline/offline"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig")) if path.exists() else None


def pcm(path):
    with wave.open(str(path), "rb") as source:
        assert source.getsampwidth() == 2
        rate, channels = source.getframerate(), source.getnchannels()
        samples = np.frombuffer(source.readframes(source.getnframes()), dtype="<i2").reshape(-1, channels)
    return rate, samples


def write_wav(path, samples, rate=48000):
    with wave.open(str(path), "wb") as target:
        target.setparams((2, 2, rate, 0, "NONE", "not compressed"))
        target.writeframes(samples.astype("<i2").tobytes())


def level(value):
    return round(20 * math.log10(max(float(value), 1e-12)), 2)


signals = {}
for path in sorted(AFTER.glob("*.wav")):
    rate, samples = pcm(path)
    values = samples.astype(float) / 32768
    signals[path.stem] = {
        "seconds": len(samples) / rate,
        "peak_dbfs": level(np.max(np.abs(values))),
        "rms_dbfs": level(np.sqrt(np.mean(values**2))),
        "clipped_samples": int(np.sum(np.abs(samples.astype(np.int32)) >= 32767)),
        "finite": bool(np.all(np.isfinite(values))),
    }

for name in ["rock_crash", "tree_crash"]:
    rate, a = pcm(BEFORE / f"{name}.wav")
    _, b = pcm(AFTER / f"{name}.wav")
    silence = np.zeros((int(rate * .6), 2), dtype="<i2")
    write_wav(OUT / f"{name}_before_after.wav", np.concatenate([a, silence, b]), rate)

equipment_reel = []
for name in ["carbon_shaft", "metal_clink", "mixed_knock", "binding_rattle"]:
    _, data = pcm(AFTER / f"{name}.wav")
    equipment_reel.append(data)
    equipment_reel.append(np.zeros((24000, 2), dtype="<i2"))
write_wav(OUT / "equipment_auditions.wav", np.concatenate(equipment_reel))

unchanged = {}
for name in ["glide", "carve", "skid", "powder", "deep_powder", "packed", "wind_packed", "ice", "groomed", "rock_scrape", "landings", "snow_crash", "body_slide", "near_misses"]:
    unchanged[name] = hashlib.sha256((BEFORE / (name + ".wav")).read_bytes()).digest() == hashlib.sha256((AFTER / (name + ".wav")).read_bytes()).digest()

suites = {}
for name in ["equipment_audio_suite", "sfx_audio_suite", "sfx_ragdoll_suite", "physics_suite", "runtime_suite", "wind_audio_suite", "sfx_fallback", "sfx_device"]:
    folder = ROOT / "artifacts/guarded" / ("natural_" + name)
    stdout = folder / "stdout.log"
    stderr = folder / "stderr.log"
    if not stdout.exists():
        continue
    summaries = []
    for line in stdout.read_text(encoding="utf-8-sig").splitlines():
        if "RESULT" in line and "{" in line:
            try:
                summaries.append(json.loads(line[line.index("{"):]))
            except json.JSONDecodeError:
                pass
    suites[name] = {"result": summaries[-1] if summaries else None,
                    "stderr": stderr.read_text(encoding="utf-8-sig") if stderr.exists() else "",
                    "guard": read_json(folder / "guard.json")}

benchmarks = {}
for key, label in [("before", "natural_audio_before_quiet"), ("after", "natural_audio_after_quiet"),
                   ("after_repeat", "natural_audio_after_repeat")]:
    data = read_json(ROOT / "artifacts/pc_environment" / label / "natural_audio.json")
    guard = read_json(ROOT / "artifacts/guarded" / label / "guard.json")
    if data and guard:
        samples = guard.get("samples", [])
        data["max_process_private_bytes"] = max((s.get("task_private_bytes", 0) or 0 for s in samples), default=0)
        data["minimum_free_bytes"] = min((s["free_bytes"] for s in samples if s.get("free_bytes") is not None), default=0)
        data["guard_exit_code"] = guard.get("exit_code")
    benchmarks[key] = data

sources = ["native/wind/sfx_dsp.h", "native/wind/sfx_stream.cpp", "native/wind/sfx_dsp_test.cpp",
           "native/wind/wind_dsp.h", "scripts/main.gd", "scripts/presentation/procedural_sfx.gd",
           "scripts/presentation/riding_audio_events.gd", "scripts/presentation/equipment_audio_contacts.gd",
           "scripts/core/ski_simulation.gd", "scripts/presentation/skier_visual.gd",
           "scripts/presentation/skier_equipment.gd", "tests/sfx_audio_suite.gd", "tests/equipment_audio_suite.gd",
           "tests/natural_audio_benchmark.gd", "tests/natural_audio_playtest.gd",
           "docs/SKIING_AUDIO.md", "addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll"]
shared_hashes_match = None
final_dll_measured = None
if benchmarks["before"] and benchmarks["after"]:
    previous = benchmarks["before"]["source_sha256"]
    current = benchmarks["after"]["source_sha256"]
    allowed = {"native/wind/sfx_dsp.h", "addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll"}
    shared_hashes_match = all(previous.get(k) == v for k, v in current.items() if k not in allowed)
    final_dll_measured = current["addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll"] == hashlib.sha256((ROOT / "addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll").read_bytes()).hexdigest()
repeat_hashes_match = (benchmarks["after"]["source_sha256"] == benchmarks["after_repeat"]["source_sha256"]
                       if benchmarks["after"] and benchmarks["after_repeat"] else None)
world_hashes_match = (len({(b["height_sha256"], b["obstacle_sha256"]) for b in benchmarks.values() if b}) == 1)
captures = {}
for name, path in [("equipment_fixture", OUT / "rendered/equipment_impacts.wav"),
                   ("skiing_crash", ROOT / "artifacts/sfx/capture/skiing_crash.wav")]:
    rate, data = pcm(path)
    captures[name] = {"sample_rate":rate, "seconds":len(data)/rate,
                      "peak_dbfs":level(np.max(np.abs(data.astype(float)))/32768),
                      "clipped_samples":int(np.sum(np.abs(data.astype(np.int32)) >= 32767))}
report = {"native": read_json(AFTER / "dsp.json"), "signals": signals,
          "unchanged_auditions_byte_identical": unchanged, "suites": suites, "benchmarks": benchmarks,
          "rendered": read_json(OUT / "rendered/report.json"),
          "reference": read_json(OUT / "reference_analysis.json"), "device_captures":captures,
          "benchmark_shared_source_hashes_match":shared_hashes_match,
          "benchmark_measured_installed_dll":final_dll_measured,
          "benchmark_repeat_source_hashes_match":repeat_hashes_match,
          "benchmark_world_checksums_match":world_hashes_match,
          "skiing_crash":read_json(ROOT / "artifacts/sfx/capture/report.json"),
          "source_sha256": {s: hashlib.sha256((ROOT / s).read_bytes()).hexdigest() for s in sources},
          "listening_acceptance": "User rejected the old-DSP live baseline, then liked the revised metal but found it glass-like. Final brighter carabiner-reference tuning is supplied for listening; naturalness, repetition and skiing comfort remain user acceptance criteria."}
(OUT / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

lines = ["# Natural equipment and impact audio", "",
         "Rock/tree A/B files play **old sound first**, a 0.6-second gap, then **new sound** at the same trigger strengths. No loudness normalization was applied.", "",
         "- [Rock impacts: old then new](rock_crash_before_after.wav)",
         "- [Tree impacts: old then new](tree_crash_before_after.wav)",
         "- [Metal fitting clinks](after/offline/metal_clink.wav)",
         "- [Carbon shaft ticks](after/offline/carbon_shaft.wav)",
         "- [Mixed equipment knocks](after/offline/mixed_knock.wav)",
         "- [Binding rattles](after/offline/binding_rattle.wav)",
         "- [Equipment with skiing and wind](after/offline/natural_skiing_mix.wav)", "",
         "Each isolated equipment file has four strikes, at 0.5, 2, 8 and 20 m/s closing speed (0.25, 1.65, 3.05 and 4.45 seconds). Carbon and metal contacts intentionally have different sounds.", "",
         "The final metal has eight independently damped modes from 5.8 to 14.4 kHz, guided by the downloaded small-carabiner reference. It uses a tiny contact attack and irregular short restrikes for rattles. The reference WAV remains external and unmodified; game audio is procedural. Tests and automated benchmarks are muted at their output bus; recording occurs before that gain.", "",
         "## Verification", "",
         "| Check | Result |", "|---|---|"]
native = report["native"]
lines.append(f"| Native DSP, 44.1/48 kHz | {native['checks']} checks, {native['failures']} failures |")
lines.append(f"| Combined wind/SFX, including eight metal voices | p99 {native['combined_p99_512_ms']:.4f} ms per 512 frames; budget 0.5 ms |")
for name, data in suites.items():
    result = data["result"]
    if result:
        lines.append(f"| {name} | {result.get('checks', '?')} checks, {len(result.get('failures', []))} failures |")
lines += [f"| Unchanged sound auditions | {sum(unchanged.values())}/{len(unchanged)} byte-identical |",
          f"| Exported PCM | {len(signals)} files; {sum(s['clipped_samples'] for s in signals.values())} clipped samples |", "",
          "## Matched 4K performance", "",
          "Default v13 seed 849205174, validated shared cache, High, 75% FSR2, 120 FPS cap, GI off. Fixed equipment poses and velocity at two sites in the full mountain, with repeated impact/equipment events. This measures audio overhead in a rendered world; it is not a full descent or a 90/120 FPS floor guarantee.", "",
          f"Shared benchmark source/asset hashes match: **{shared_hashes_match}**. Final installed DLL was measured: **{final_dll_measured}**. Height/obstacle checksums and exact display settings are recorded in the JSON.", "",
          "| Pass / site | Frame p95 / p99 ms | CPU p95 / p99 ms | GPU p95 / p99 ms | SFX callback p99 ms |",
          "|---|---:|---:|---:|---:|"]
memory_lines = []
for key, data in benchmarks.items():
    if data:
        for p in data["passes"]:
            lines.append(f"| {key} / {p['section_m']} m | {p['frame_ms']['p95']:.3f} / {p['frame_ms']['p99']:.3f} | {p['cpu_ms']['p95']:.3f} / {p['cpu_ms']['p99']:.3f} | {p['gpu_ms']['p95']:.3f} / {p['gpu_ms']['p99']:.3f} | {p['native_sfx']['p99_512_ms']:.4f} |")
        memory_lines += ["", f"{key}: peak task private memory {data['max_process_private_bytes']/2**30:.2f} GiB; minimum free physical memory {data['minimum_free_bytes']/2**30:.2f} GiB; maximum Godot-reported video allocation at the two measured sites {max(p['video_bytes'] for p in data['passes'])/2**30:.2f} GiB.", ""]
    else:
        lines.append(f"| {key} | Not measured | | | |")
lines += memory_lines
lines += ["Native diagnostics include warmup; capture overhead is excluded. The initial final-DLL run had a 14.71 ms frame p99 at the first site; an unchanged-source repeat returned 8.50 ms there and 8.49 ms at the second site. The spike did not reproduce, and its cause is unresolved. All runs are retained; the repeat does not establish a hard FPS floor or a zero-cost change.", "",
          f"Repeat source/DLL hashes match: **{repeat_hashes_match}**. World height/obstacle checksums match across all three runs: **{world_hashes_match}**.", "",
          "The stress fixture deliberately overruns transient availability; voice drops are bounded prioritization, not queue corruption. See JSON for counts.", "",
          "## Rendered and listening evidence", "",
          "[Rendered contact fixture](rendered/equipment_impacts.mp4) · [device-mixed PCM](rendered/equipment_impacts.wav). Carbon and tip chapters use the live geometric observer. Later chapters directly submit labelled equipment and material events. The separate ragdoll suite checks actual Jolt contact routing.", "",
          "[In-game skiing/crash video](../sfx/capture/skiing_crash.mp4) and [PCM](../sfx/capture/skiing_crash.wav) use the laboratory fixture and ordinary solver/ragdoll behavior. This capture included readback and a background game, so its frame timing is not part of the isolated comparison. Two bounded acoustic sweeps exhausted their iteration budget and were silently discarded; collision geometry and physics were unaffected.", "",
          "Signal checks, rendered frames and a working device callback do not establish naturalness, repetition or long-session comfort. Final listening/skiing acceptance remains with the user.", "",
          "[Full measured results and source/DLL hashes](validation.json)"]
(OUT / "AUDITIONS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(json.dumps({"native_checks": native["checks"], "pcm_files": len(signals), "unchanged": unchanged,
                  "benchmarks": {k: v is not None for k, v in benchmarks.items()}}))
