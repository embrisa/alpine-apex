# Interface overhaul native performance evidence

`tests/interface_performance_suite.gd` is the bounded native evidence runner for
AA-20260911-163058-interface-overhaul. The protocol below separates steady
rendering, moving simulation, UI overhead, native GPU correctness and display
recovery. Measured results and remaining acceptance are recorded at the end.

## Execution

Finish concurrent source edits first. Use the existing validated v15 Standard
physical/scenery caches and custom DX12 engine. The suite calls exactly
`MountainDefinition.generate(849205174,15)`, passes the result through the normal
`mountain_to_load` handoff, instantiates `main.tscn`, and waits for initialization
and loading completion. It never selects `test_lab_fixture` or substitutes a
render-only world. A physical cache miss invalidates the comparison; the existing
generate API may bake a missing/stale cache before returning, so prepare/validate
the cache separately under the parent's guard before this run.

Run this **after** the parent's parsing/functional checks, from the project root:

```powershell
. ./scripts/resolve_godot_engine.ps1
$interfaceEngine = Get-AlpineGodotEngine -ProjectRoot $PWD.Path
$interfaceArgs = @(
    '--path', $PWD.Path,
    '--rendering-driver', 'd3d12',
    '--script', 'tests/interface_performance_suite.gd', '--',
    '--ui-staged-loading', '--benchmark-no-captures',
    '--graphics-quality=high', '--upscaler=auto', '--render-scale=0.75',
    '--fps-limit=120', '--frame-generation=off', '--terrain-gi=off',
    '--interface-performance-output=artifacts/interface_overhaul/performance',
    '--interface-display-checks', '--interface-matched-ui'
)
./scripts/run_guarded.ps1 -FilePath $interfaceEngine -Arguments $interfaceArgs `
    -Label interface-performance -TimeoutSeconds 1800 -CollectGpuMemory
```

The guard owns `artifacts/validation.lock`; do not nest another guard or use
`-AllowConcurrent`. It records working set, private bytes, GPU process allocation
and background driver events, and stops on engine errors, device failures or its
wall-clock limit. If a parent already owns the guard, invoke the resolved engine
within that same guarded job instead. Keep ordinary competing GPU workloads out
of comparative runs without terminating the user's apps.

Capture driver/OS identity alongside the guard's memory telemetry:

```powershell
@{
    utc = [DateTime]::UtcNow.ToString('o')
    gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,DriverDate)
    cpu = @(Get-CimInstance Win32_Processor | Select-Object Name)
    system = Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory
    os = Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber
} | ConvertTo-Json -Depth 5 | Set-Content artifacts/interface_overhaul/machine-performance.json
```

The output folder can be changed with `--interface-performance-output=...`.
Use a different folder for repeat attempts. `--interface-no-captures` disables
post-measurement PNGs and the visual timeline, so that run lacks visual evidence.
`--interface-display-checks` opts into the self-restoring output/FG helper. Omit
it when only steady performance evidence is wanted; report that native display
acceptance remains open. Do not enable GPU validation/debug layers for reported
performance; run those separately if diagnosing a failure.

## Workloads and bounds

| Workload | Protocol |
| --- | --- |
| Ten actual presets | 1 through 10, each at clear summit and snowfall forest: 5 seconds settling + 10 seconds samples, 300 seconds total |
| Moving routes | Summit 1/7/10, forest 10/7/1: 5 seconds settling + at least 30 wall seconds and 3600 production solver ticks each; normally 210 seconds total |
| High UI | Menu, Display settings, expanded Graphics scroll, category transitions, moving riding HUD; each with full/reduced motion; 120 warmup + 240 sample frames |
| Native powder | Production history/buffer across 7→8→9→10→7→1→7→10; readback stress at every 8/9/10 occurrence, outside timing |
| Visual timeline | Five chronological one-second-spaced descent captures each in full/reduced motion; separate from all timing |
| Optional display/FG | Keep, Revert, real 15-second timeout, native-sized Windowed, fullscreen FG off/on/off; no monitor switch or persisted preferences |

The 900-second cooperative ceiling starts immediately after physical cache load,
**including scene construction**, rather than after the first sample. Moving
cases have a 60-second wall ceiling to accumulate 3600 actual solver ticks even
below target FPS; fixed/UI cases have 30-second local ceilings. Native readbacks
have five-second response deadlines. The outer guard handles a blocked engine,
render thread or synchronous load where GDScript cannot service its deadline.
Normal steady/settling work is about nine minutes, leaving time for submission,
readbacks, PNGs and the optional output matrix. Progress prints begin each case,
continue every ten measured seconds, and report a result after each case.

Both fixed camera transforms are checked for stability within the case and
across presets. They keep production scenery/weather/effects running with only
physics processing held. The forest location uses the existing native fixture's
bounded passage search and obstacle-clearance API; its actual coordinates enter
the manifest. All cases use 3840×2160 output, Auto reconstruction at 75%, cap 120,
FG off and GI off. Ultra can fall below the target; no FPS-target assertion
incorrectly treats that agreed behavior as a correctness failure.

Moving routes use `main.benchmark_input` at 120 Hz, ordinary RiderInput, normal
simulation/contact, pose, chase camera, HUD, audio, scenery and effects. Input is
fixed by tick: tuck .35, brake .08, steering `.10*sin(tick/240)`. A crash, base,
inactive segment or 3600-tick segment end restarts the identical site and input.
Restart cost remains in timing, with every restart and completed moving tick
recorded. Same-tick position/velocity/heading checkpoints are compared across
presets. These are repeated unranked segments, **not successful full descents**.
Haptic hardware output is disabled; motion/camera/audio settings are recorded.

The historical `interface_suite.gd` settings protocol is retained exactly at
120 warmup and 240 samples. Its captured High means the old asset tier 2; the
new corresponding preset is 7. The reduced-motion settings row matches its
4K/Auto75/cap120/FGoff and muted riding/UI audio, camera-motion-off setup. Other
rows explicitly record their different motion state. All Graphics groups are
expanded for scrolling; transitions change categories every 20 samples. The
historical JSON did not capture exact recipe, camera or source identity, so this
is a protocol comparison, not a controlled before/after regression claim.

## Evidence and interpretation

`results.json` checkpoints after each case; `completed` becomes true only on a
clean finish. Each timed case also writes its unsorted raw sample arrays. Record:

- Engine binary SHA-256/version/backend/device, code/shader/config hashes,
  canonical Standard recipe/cache keys, seed, model/height/obstacle identity,
  cache hit/stages, physical read and scene/submission costs separately.
- Actual preset/profile and discrete asset tier; actual particle allocations,
  track capacity, shadow range, weather allocation, live texture resource paths,
  environment, forest residency, powder upload budget and camera settings.
- Actual output image readback and window size; actual temporal viewport mode
  and .75 scale; output-viewport HUD ownership and canvas-items scaling.
  Logical UI coordinates are allowed to scale while UI draws at output pixels.
- Frame mean/p95/p99, total-throughput rendered FPS (`1000/mean_ms`), instantaneous
  FPS distribution, and FPS corresponding to p95/p99 frame times. The last two
  are low-FPS tail measures; p95 FPS itself is an upper percentile.
- Render CPU/GPU times, application and physics process monitor times, scoped
  CPU costs in microseconds, draw calls, engine static/video allocation
  distributions and first/last video allocation. Join guard telemetry by time
  for OS RAM and process GPU allocation; renderer counters are not total RAM.
- Separate native upscale/rendered/generated/present counters and errors.
  FG-off rendered presents must agree with sampled process frames within four
  frames or 2%; native rendered FPS is also recorded directly from that counter.
  Native FG counters do not establish monitor delivery or latency.

No screenshots, GPU texture/buffer readbacks, JSON writes or material enumeration
occur inside steady samples. Case progress messages and the bounded measurement
arrays/scopes are instrumentation overhead. Preset `application_ms` is the
synchronous apply call only; settling and deferred rendering costs are separate.
The script rehashes sources at the end and fails if source identity drifted.
Binary texture content is not exhaustively hashed; live resource paths and the
validated scenery/cache identity identify the installed asset configuration.

The native SDK's current `get_status()` has no internal texture-size fields.
The reported **2880×1620** is derived from verified output readback and the actual
viewport scale, just as the baseline report did; it is not independent SDK
texture readback. Do not invent `render_width`/`display_width` status keys. External
GPU inspection is still required if independent internal-resource proof is needed.

The powder helper freezes the ordinary producer, fills every history slot with
finite nonzero strokes, exercises maximum-capacity wrap spans plus both live
slots, reads the real native storage buffer, and compares partial/full/repeated
native relief textures byte-for-byte. It requires finite nonzero relief and
stable buffer/texture RIDs and byte allocation. This is synthetic allocation and
dispatch evidence; moving production samples supply natural deformation evidence.
The helper restores history and the normal producer afterward.

The display helper only proceeds on a currently selected native 4K monitor. It
uses the actual main preview/Keep/Revert callbacks and real timeout clock,
checks exact window recovery, and disables FG/restores preferences and actual
window geometry on checked failure. Stores remain isolated by script/automated
mode. It changes only this process's window/swapchain; an external guard kill
closes that window. Unsupported FG or unsuitable monitor dimensions are explicit
skips, not passes. Physical monitor movement, monitor loss, user confirmation
and controller operation remain separate acceptance work.

Inspect stderr/guard status and chronological PNGs before reporting acceptance.
A native runner success proves its measured protocols and assertions, not visual
quality, complete-descent comfort, rendered target attainment or user/controller
acceptance. Actual results and remaining gates follow below.

## Reproducing the paired layout comparison

`--interface-matched-ui` additionally measures menu, actual Camera-page scrolling,
category transitions, stationary riding-HUD and moving forest views before/after. The old HUD
builder comes from the task's initial `6830997` revision. Both HUDs remain resident
and updated in both halves; only the visible layout differs. Current shared
camera/feedback/records components and the same current renderer/world are used
in both halves. This isolates layout cost and is not a whole-engine historical
benchmark. Isolated update-call CPU cost is measured separately; the full runner
also measures ordinary production moving routes without a second resident HUD.

Prepare the historical fixture without modifying current source:

```powershell
@'
from pathlib import Path
import subprocess
p = Path('artifacts/interface_overhaul/baseline/hud.gd')
p.parent.mkdir(parents=True, exist_ok=True)
p.write_bytes(subprocess.check_output(['git','show','6830997:scripts/ui/hud.gd']))
'@ | python -X utf8 -
```

Use `--interface-phase=matched` (or `fixed`, `moving`, `ui`, `powder`, `timeline`,
`display`) with a separate output directory for a focused repeat after a failed
fixture or a relevant change. The default `all` runs the complete protocol. A
phase-only report establishes only that phase; it never implies the others ran.

## Measured results — 2026-09-11

The guarded full execution completed 48 result rows and 54 captures, with no
protocol failures, engine errors or recorded background driver/app errors. A
second execution after the bounded popup-registration fix completed 11 paired
rows, including 30-second moving HUD comparisons and isolated CPU update calls.
The display execution passed six rows and captured four recovery states.

Machine: Ryzen 5 5600X (6 cores/12 threads), RX 9070, 16 GB RAM, Windows 11
26200; driver 32.0.31041.1004. Custom Godot 4.7.2, DX12, FSR 4.1.1, 3840×2160
output, .75 viewport scale (inferred 2880×1620 internal), 120 FPS cap, FG/GI off.
Seed 849205174, generator v15 Standard, model 28, validated warm physical and
scenery caches. Each execution records exact engine/source/recipe identities in
[the maintained result data](INTERFACE_PERFORMANCE_RESULTS.json).

Each fixed view settles for five seconds and measures ten seconds. Values are
rendered FPS and frame-time percentiles; screenshot work is excluded.

| Preset | Summit FPS | Forest FPS | Forest p95 / p99 (ms) | Forest CPU / GPU mean (ms) |
|---|---:|---:|---:|---:|
| 1 | 120.01 | 120.00 | 8.464 / 8.525 | 1.065 / 5.987 |
| 2 | 120.00 | 120.00 | 8.388 / 8.484 | 1.068 / 5.652 |
| 3 | 120.01 | 120.01 | 8.390 / 8.460 | 1.055 / 5.888 |
| 4 | 119.72 | 120.01 | 8.388 / 8.477 | 1.123 / 6.243 |
| 5 | 111.44 | 120.01 | 8.386 / 8.423 | 1.164 / 6.242 |
| 6 | 119.82 | 119.26 | 8.642 / 11.238 | 1.465 / 6.554 |
| 7 | 119.91 | 107.38 | 9.734 / 10.318 | 1.384 / 8.729 |
| 8 | 119.17 | 104.03 | 10.018 / 10.366 | 1.357 / 9.050 |
| 9 | 120.01 | 99.21 | 10.544 / 10.938 | 1.507 / 9.503 |
| 10 | 119.57 | 95.14 | 11.584 / 13.141 | 1.791 / 9.764 |

Preset 5’s summit sample showed CPU-tail variation (111.44 FPS, p95 12.114 ms);
its forest sample recovered to 120 FPS. This outlier remains in the report.

Each moving sample covers at least 30 wall-clock and simulation seconds, with
identical 120 Hz inputs and matching same-tick state checkpoints across presets.
Resets at 3,600 ticks/crash/base remain in the data; these are bounded route
segments, not complete mountain descents.

| Preset / route | FPS | p95 / p99 (ms) | Render CPU / GPU mean (ms) | Distance (m) |
|---|---:|---:|---:|---:|
| 1 / summit | 116.73 | 9.840 / 13.747 | 1.095 / 5.035 | 269.1 |
| 7 / summit | 112.79 | 12.400 / 15.054 | 1.341 / 6.793 | 268.9 |
| 10 / summit | 101.03 | 15.092 / 17.770 | 1.843 / 7.340 | 268.9 |
| 10 / forest | 87.61 | 14.508 / 15.804 | 1.294 / 10.313 | 36.6 |
| 7 / forest | 88.42 | 15.462 / 26.549 | 1.336 / 9.549 | 36.6 |
| 1 / forest | 107.69 | 13.405 / 16.859 | 1.031 / 5.673 | 36.8 |

**Preset 7 has not met the sustained target.** Its summit p95 misses 11.1 ms;
the snowy forest misses average 90 FPS, p95 11.1 ms and p99 16.7 ms. Ultra also
misses tail targets, as allowed. Fixed views do not establish moving performance.
No preset was reduced to conceal these results and no generated frames were
counted. Larger measured costs are GPU rendering, 120 Hz simulation/animation
and rendered poses; the production HUD scope averages .165–.175 ms in the two
preset-7 routes. These measurements warrant further subsystem profiling, not a
claim that changing the UI solved overall gameplay performance.

The final paired layout run uses the same renderer/world/initial camera and
keeps both HUDs resident and updated. The moving pair also uses the same input
and finishes at the same 3,601-tick state. This measures visible layout/draw
changes; it does not subtract the common update cost of both HUDs.

| Workload | Before / after FPS | Before p95 / p99 (ms) | After p95 / p99 (ms) |
|---|---:|---:|---:|
| menu | 120.01 / 120.01 | 8.499 / 8.532 | 8.458 / 8.522 |
| settings scroll | 120.01 / 120.01 | 8.470 / 8.502 | 8.490 / 8.552 |
| settings transition | 112.72 / 112.69 | 9.859 / 44.585 | 9.761 / 44.849 |
| riding hud | 120.01 / 120.01 | 8.458 / 8.508 | 8.451 / 8.534 |
| moving forest hud | 77.25 / 74.46 | 25.656 / 38.479 | 22.143 / 31.289 |

The moving pair’s mean frame time rises .486 ms (3.8%) while both tail values
improve; render CPU rises .196 ms and GPU .081 ms. This single pair does not
establish a causal gameplay regression. Alternating 500 isolated update calls
measure 44.19 µs before and 92.12 µs after: an added .048 ms for the configurable
widget layout. No material stationary layout regression is demonstrated. The
paired transition fixture updates both old and new page trees and has shared
transition spikes; the production-only reduced-motion transition sample is
120 FPS with p95 8.383 / p99 8.437 ms. Keep these protocols distinct.

All execution peak task working set / private bytes: 2.27 / 6.35 GiB. Paired execution peak task working set / private bytes: 2.05 / 5.74 GiB. These are process-lifetime peaks including loading/capture work, not steady
frame allocations. Per-row static/video counters and guard process-GPU
allocation telemetry are retained; Windows allocation totals can double-count
shared resources and are not physical VRAM capacity.

Native powder checks filled 4,608 / 5,376 / 6,144 history slots plus two live
slots, crossed ring boundaries, and read back actual GPU buffers and textures.
Partial/full/repeated relief results were byte-stable, finite and nonzero; the
196,672-byte buffer and texture allocations stayed stable through tier changes.

Inspected chronological full/reduced-motion descent stills and the native UI,
HUD-editor, text-entry, camera-preview and recovery captures. Still-image HUD FPS
readouts include readback/PNG overhead and must not be used as benchmark values.
Actual mixer capture covers all six UI cues, repeated input, volume/mute and
loading ambience; physical listening and real-controller comfort remain open.

The full timing run used milestone `6f5ef8d`; the expanded paired run used
`8024088`. Exact source hashes are in the result data. A subsequent small-screen
navigation-rail visibility correction was verified natively; these timings were
not repeated for that UI-only correction. The 4K measured rail already fit all
categories. Neither update changed renderer budgets or simulation.
