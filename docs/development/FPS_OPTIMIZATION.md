# Skiing FPS optimization

This pass preserves the output resolution, render scale, lighting/GI, scenery
density, LOD distances, shadows, effects and snow reconstruction. It changes
render submission and forest preparation, without changing the ski solver,
terrain authority, input interpretation, camera geometry or art assets.

## Implemented paths

- World-owned exact-value caches suppress repeated environment, light, material
  and wind submissions. Quality changes invalidate the cache; new cloud-light
  receivers immediately receive the current state. Animated cloud displacement
  and wind time still advance on every normal update.
- The powder history remains in its existing GPU storage buffer. Track writes
  expose immutable byte spans; the renderer submits those spans plus the two
  current ski footprints. Ring wrap can produce two spans. Reset, capacity
  changes, first use and excessive pending fragmentation force a complete sync.
  The same 4096-stroke High history, 1024 atlas, 256 filtered map, 512-subdivision
  patch and three compute passes remain in use.
- Forest regions prepare their packed transforms and original conservative
  bounds during loading. Near, middle and shadow batches reuse this data and
  preloaded mesh resources. The 128 m load radius, 192 m retention radius,
  nearest-first ordering, three regions per frame and all detail/shadow ranges
  remain unchanged. The middle and shadow instances share one immutable
  MultiMesh while keeping their own material overrides and visibility. Its
  prepared bound also avoids native bound reconstruction during bulk upload.
  Shared GPU placements are released with the original residency window.
  Packed placements add 48 bytes per tree (9.6 MB for 200,000), plus metadata.

## Reproduce a matched performance comparison

Generate an ordinary-input trace after any physics/terrain identity change:

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--headless','--script','tests/performance_trace.gd') -Label fps_trace -TimeoutSeconds 1200
```

The offline test pilot supplies ordinary rider inputs; it does not move the
skier or alter the solver. Only a complete, uncrashed descent becomes a trace.
Its core/generator/tuning hashes, model version and terrain checksums are
validated before playback. Route planning is never part of measured gameplay.
`--trace-output=artifacts/fps_optimization/live_descent_input.json` can
preserve a separate comparison trace while validating the current game.
Use a relative output here: PowerShell's script-argument parser can split an
inline `res://` URI at its colon. The trace writer resolves relative paths from
the project root and reports file errors explicitly.

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','fps_current','-Upscaler','fsr4','-TerrainGI','on','-FrameGeneration','off','-FrameCap','0','-Repetitions','3','-ProfileFrameCosts') -Label fps_current -TimeoutSeconds 1800 -CollectGpuMemory
```

Run the same configuration with `-FrameGeneration on` to check the saved user
configuration. Generated presentations never count as rendered FPS. All runs
are unranked and read camera preferences without saving them. Graphics options
are process-local. No existing applications are stopped.

`production.json` contains whole-descent and section frame distributions,
CPU scopes in microseconds, GPU/render-thread times in milliseconds, draw calls,
engine memory, snow/forest budgets and FidelityFX status. `system.json` records
the engine hash, before/after source manifests, process/system RAM and available
Windows GPU allocation counters. A source mismatch invalidates a paired result.
Windows allocation totals and engine video-memory estimates are different
measurements; neither should be presented as precise physical VRAM occupancy.

The section labels describe radial bands along this particular route:
open below 700 m, powder 700–1300 m, minerals 1300–1900 m and forest beyond
1900 m. They are useful repeatable route sections, not a classification of
every surface inside a band. Report individual descents and medians of their
statistics; do not pool percentiles or promise a full-mountain minimum from
an average. Three repeated descents also expose residency/memory trends.

## Correctness and visual evidence

```powershell
./scripts/validate_render_efficiency.ps1
./scripts/validate_render_efficiency.ps1 -NativeOnly
```

The semantic suite checks cached lighting, late material registration, byte
span reconstruction through ring wrap/reset/quality changes, and exact packed
transforms/bounds. The native powder suite compares partial and complete buffer
uploads through the same compute shader and reads back the filtered map.
Standard physics/runtime, graphics, density/LOD, powder and FidelityFX settings
suites remain separate regression checks.

`weather_submission_benchmark.gd`, `forest_submission_benchmark.gd` and the
native powder suite's `--profile-uploads` mode isolate submission costs. They
support diagnosis and component-level decisions; their smaller workloads do
not establish gameplay FPS. Preserve rejected attempts alongside the final
full-descent comparison so a bandwidth saving or favorable microbenchmark
cannot conceal an overall regression.

Use `tests/performance_visuals.gd` with `--fixed-fps 60` and matching graphics
arguments to capture clear/snowfall, chase/first-person stills and moving
sequences at four trace-derived sites. These captures are separate from timing.
`tests/performance_tracks_visual.gd` adds a paused close inspection and short
camera orbit over tracks left by ordinary skiing on the same mountain. Its
inspection camera changes only the test view; production camera code is intact.
Fixed particle seeds help comparison; temporal upscaling, GI and particle
history can still produce pixel differences. Inspect appearance and motion,
not only image difference scores. Normal user skiing is the final acceptance
gate for smoothness, unchanged appearance and device feel.

Reports and matched evidence from this run live under
`artifacts/fps_optimization/`; performance logs live under
`artifacts/pc_environment/fps_*`. These are disposable local evidence, not
portable benchmark guarantees.

## 2026-09-10 measured comparison

The final reference and candidate each completed three identical 334-second
descents. Both use seed 849205174/v14 and the same frozen model-26 gameplay
sources, tuning, input trace, production chase camera and complete gameplay
update loop. The live project advanced to model 27 in concurrent handling work;
its integration check is reported separately rather than mixed into this pair.

| Median of three full descents, frame generation off | Before | Optimized |
|---|---:|---:|
| Rendered FPS | 96.79 | 99.97 |
| p95 frame time | 13.989 ms | 13.820 ms |
| p99 frame time | 16.563 ms | 16.448 ms |
| Mean GPU time | 8.388 ms | 8.167 ms |
| Weather/world CPU per call | 196.39 us | 153.88 us |
| Snow/powder CPU per call | 124.53 us | 111.37 us |
| Forest residency CPU per call | 40.94 us | 36.64 us |

This is a modest 3.28% median FPS improvement, with run-to-run variation. The
first optimized descent was slightly slower (93.16 versus 94.56 FPS); the two
warmed repeats improved. The mineral section's p95/p99 worsened slightly even
though overall and forest percentiles improved. The 11.1 ms p95 target remains
unmet, and the first optimized descent also exceeds the 16.7 ms p99 target.
Average FPS alone does not establish the requested smoothness target.

Forest packing uses 9.6 MB of float data; engine allocation growth including
region metadata is about 44 MiB. End-of-descent residency remains exactly 31
regions and 8,621 batches on this route. Engine memory increased about 0.05 MiB
between the second and third optimized descents, while engine video-memory
estimates stayed flat. This does not suggest accumulating forest residency over
these repeats; it is not an indefinite-duration leak test.

Isolated native comparisons independently reduced weather submission CPU by
about 30%, forest batch creation CPU by 45%, and powder upload/reconstruction
frame intervals by 9%. The gameplay scope measurements above are the relevant
full-loop result. Simulation and animation scopes execute at 120 Hz; powder is
nested inside effects, so these per-call means must not be added together.

The initial generic property cache made weather submission slower and was
replaced with grouped stable-state checks. An earlier reference also ran faster
than its later unchanged repeat, showing changed run conditions. The final
report uses the refreshed unchanged reference and preserves earlier and
rejected attempts for audit. All workloads were serialized with the shared
validation lock, and existing applications remained running.

A final late-registration fix retains the known wind state across quality-cache
invalidation. It changes registration only, with no extra normal update-loop
work; the three FG-off descents predate this corner-case fix. Subsequent native
captures, FG-on and live integration checks use the fix.

See [full measurements](../../artifacts/fps_optimization/measurements.md) for each
run, route sections, memory and upload data. Saved graphics and camera settings
are checked against their original hashes. Matched visual evidence and live
regression results are kept alongside this report; normal user skiing remains
the final appearance and smoothness acceptance gate.

The saved frame-generation-on fullscreen configuration also completed one
before/after descent, but generation was inactive with zero generated frames
during both measured intervals. That pair was unfavorable (97.52 to 90.89
rendered FPS), so the FG-off gain is not a claim that the complete saved
configuration improved. `tests/fidelityfx_benchmark_probe.gd` isolates the
behavior: generation works at 1080p and at 4K borderless windowed output, but
becomes inactive at 4K fullscreen. Readback is not the cause. The optimization
pass leaves the saved display mode and engine integration unchanged.

All 11 regression suites passed. The live model-27 playback reached its exact
expected endpoint, but a concurrent animation-source edit during that run makes
its FPS unsuitable for a stable-build comparison. The frozen model-26 pairs
above remained source-stable. See [consolidated results](../../artifacts/fps_optimization/RESULTS.md)
and [17 matched visual comparisons](../../artifacts/fps_optimization/visual_comparison/review.md).
Sampled-frame review found no appearance regression; its forest clips contain
matching tree contacts and do not establish sustained high-speed forest visual
acceptance. Normal user skiing remains the final review.
