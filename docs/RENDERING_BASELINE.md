# Historical rendering baseline investigation, 2026-09-14

The [original prerequisite task](../backlog/abandoned/AA-20260914-094136-establish-repeatable-rendering-baseline.md)
was retired during the 16 September backlog grooming. This report preserves its
dated findings; its blocked gate and repeated-control/hash-audit procedure no
longer govern new work. Use [saved-baseline reuse](VALIDATION.md#reusable-baselines-and-experiment-budget)
and [current performance references](PERFORMANCE_HANDOFF.md) for new candidates.

The investigation is **blocked for total-frame comparisons**. Five unchanged forest processes exhausted the predeclared return-control budget: median frame time spread was **11.58%**, p95 **25.54%**, and p99 **20.69%**. GPU mean spread was **1.13%**. This milestone fixes a bare-snow benchmark assertion and adds receipt auditing; it delivers no runtime optimization and does not unlock downstream optimization acceptance.

[Individual trial receipt](RENDERING_BASELINE_RESULTS.json) contains all 49 timing/profile trials, including first encounters, all outliers, medians of run statistics, CPU scopes, memory and pass summaries. The detailed [run table](../artifacts/rendering_baseline_20260914/run_table.json) retains completed-tick bins, event/frame correlations and full settings. The [method](VALIDATION.md#rendering-baseline-receipt-audit) owns the maintained contract.

## Frozen workload and validity

Measured runtime: Dev 32, `7c447b368a6e79f9161856ac035fdc4045b67c46`; Standard seed 849205174, generator 15, model 35, 120 Hz, 4 m authority and 200,000 physical trees. Hardware was Ryzen 5 5600X / Radeon RX 9070, custom Godot 4.7.2 Forward+ D3D12. Output was 3840 x 2160, internal 2880 x 1620 (0.75), High 7, Auto FSR actually 4.1.1, FG/GI off. All current timing receipts report zero unfocused frames, exact 1,800-tick endpoints, no crash, 240 warmup frames and both physical/scenery cache hits. No physical regeneration occurred.

The [plan](../artifacts/rendering_baseline_20260914/plan.json) predates timing. Order was forest A1, A2, open, mineral, stress, A3; the one permitted follow-up was A4, A5. Each fresh process ran three independently warmed 15-second repetitions. Four one-repetition native profiles and a separate three-repetition 120-cap confirmation followed. Scenery preparation ran immediately before every arm because the prepared cache slot is source-specific. Timings used FpsCritical guards, preparation Exclusive, visual captures Shared, with explicit full-mountain reasons.

The [freeze receipt](../artifacts/rendering_baseline_20260914/frozen/snapshot.json) records 15,554 input hashes before measurement. Final [integrity verification](../artifacts/rendering_baseline_20260914/integrity.json) rehashed 8,609 source/hydrated-asset files plus 6,940 imported asset files in each project: no unexpected differences. The engine executable and console launcher also match their pre-run SHA-256 receipts. Other mutable `.godot` runtime state is excluded from the final comparison; `.godot/imported` bytes were checked separately. The snapshot helper's nine named baseline overrides were identical to the candidate at this revision.

The open route alone uses the recorded [harness override](../artifacts/rendering_baseline_20260914/frozen/open_override.json): enabled vegetation may naturally have zero population on bare snow. The old blanket assertion rejected that valid open control. Removing it changes only post-trial validation; grass-off zero-population checks remain. Vegetation feature-cost comparisons still require a populated on arm. Forest A1-A5 retain identical original harness bytes. Cross-route absolute differences therefore remain workload observations, not causal code comparisons.

| Workload | Travel / sampled coverage | Qualification |
|---|---|---|
| Dense ordinary forest | 73.99 m; 1,407-1,502 trees within 175 m at sampled seconds; 3.40-24.76 km/h | Scenery camera, near trunks, canopy gaps and horizon. Slow dense coverage, not high-speed ordinary descent. |
| Open ordinary | 279.72 m; zero nearby trees; 12.92-117.83 km/h | Normal summit launch and production tuck input; exposed snow and horizon. |
| Mineral shelf to snow | 41.67 m; about 193-196 nearby trees | Exposed rock and small gravel patches, then snow and sharp slowdown; not sustained mineral/high-speed coverage. |
| Controlled stress | 707.8404 m; sampled nearby trees 274-892 | 170 km/h benchmark-only speed control using the riding camera; distinct from scenery-camera arms. |

Each stress trial records 1,800 ticks, 1,273 grounded ticks, 1,800 obstacle queries, 44 nonblocking contacts and 20 prevented tree-impact failures. Speed extrema are 169.99997-170.00001 km/h. These are deliberate stress-policy events, not safe handling or crash acceptance. An initial ordinary transition candidate had 817-1,497 nearby trees and was rejected as an open control before timing. No alternate seed or local component sweep was needed.

Six separate visual receipts retain 18 native PNGs and camera positions. Inspected forest, open, mineral, stress and riding-control frames show the intended subjects; sampled ground clearances are about 2.0-5.6 m. Screenshot/inventory overhead is flagged and all such frame times are excluded. Player preference hashes (16 before timing) and the later expanded 59-file preference/current mountain/race/record snapshot are unchanged; the expanded snapshot starts at A2, so it is not evidence for pre-A1 race bytes. All timing harness receipts independently report unranked operation.

## Individual processes

Each cell below is a median of that process's run statistics; FPS lists preserve all three repetitions. Max is the median of individual run maxima, not the worst frame across all runs. Exact individual distributions are in the linked JSON.

| Process | FPS, repetitions 1 / 2 / 3 | Frame mean ms | p95 / p99 / max ms | GPU / render CPU ms | Draws / primitives M |
|---|---|---:|---|---|---|
| rb-forest-a1 | 56.75 / 64.55 / 63.26 | 15.809 | 21.937 / 26.899 / 46.013 | 12.700 / 2.501 | 1615.4 / 13.719 |
| rb-forest-a2 | 56.71 / 58.16 / 54.63 | 17.635 | 27.539 / 32.465 / 39.210 | 12.729 / 2.766 | 1627.8 / 13.871 |
| rb-open | 105.21 / 101.87 / 104.89 | 9.534 | 12.968 / 15.101 / 25.946 | 5.937 / 1.624 | 671.0 / 4.801 |
| rb-mineral | 67.61 / 68.97 / 68.73 | 14.551 | 18.354 / 21.918 / 29.085 | 9.089 / 2.379 | 1127.6 / 5.165 |
| rb-stress | 53.86 / 50.61 / 55.08 | 18.566 | 32.074 / 46.079 / 59.922 | 10.319 / 2.835 | 1460.3 / 8.041 |
| rb-forest-a3 | 55.40 / 58.02 / 60.51 | 17.234 | 25.483 / 31.321 / 39.743 | 12.618 / 2.597 | 1611.0 / 13.697 |
| rb-forest-a4 | 57.58 / 52.30 / 58.21 | 17.367 | 24.953 / 32.416 / 72.354 | 12.587 / 2.638 | 1619.6 / 13.737 |
| rb-forest-a5 | 56.69 / 56.37 / 59.23 | 17.639 | 25.993 / 30.050 / 52.762 | 12.704 / 2.698 | 1619.1 / 13.759 |
| rb-forest-cap120 | 58.07 / 59.52 / 58.72 | 17.029 | 24.103 / 27.885 / 39.636 | 12.460 / 2.553 | 1617.9 / 13.748 |

The five forest process medians span 15.809-17.639 ms (56.69-63.26 FPS); individual forest trials span 52.30-64.55 FPS. The worst A4 frame is 106.034 ms and remains included. The 120-cap confirmation produced 58.07 / 59.52 / 58.72 rendered FPS; its cap was not the limiting throughput. It is a separate condition, not an uncapped return control or 120 FPS acceptance. Current timing scene readiness spans 51.49-54.27 seconds per process, outside measured skiing; startup is shared across its three repetitions.

The predeclared gate was at most 3% process-median frame/GPU spread and 15% p95/p99 spread, computed as `(max/min - 1)*100`. Observed ranges are not statistical confidence intervals. Forest GPU means pass that narrow observed gate, but total frame and tail gates fail. Do not select only the fastest process or remove first repetitions.

## Retained audit and unresolved frame drift

The earlier colorful-forest candidate retains 67.06 / 68.24 / 68.61 FPS and median GPU mean 12.106 ms. Frozen gravel off / all / repeated off retains medians 85.24 / 91.23 / 81.06 FPS, GPU 9.234 / 8.638 / 9.714 ms. All 18 retained trials pass receipt validity. Gravel's unchanged off return drifts 5.16% in frame mean and 5.19% in GPU mean. Its matched one-second primitive ratios are about 0.994-1.002, while delayed GPU differences span roughly +0.007 to +1.376 ms. Stable counts do not identify the timing cause. Adding gravel is not established as an optimization. Historical camera/source/cap/route identities differ from the current matrix; absolute FPS is not a regression comparison.

First encounter matters: current forest collision-preparation events reach roughly 14.5-16.0 ms on first repetitions versus about 8.6-9.4 ms on later re-entry. The open route reaches 24.141 ms (terrain 23.852 ms); stress reaches 26.602 ms first and about 16.3-17.3 ms warmed. Stress grass streaming reaches 13.889 ms and forest region work 7.244 ms. These nested invocation scopes overlap and cannot be added. The machine table retains the eight largest events and eight worst frame overlaps per trial. A tiny forest-residency average does not exclude these tails.

System samples show Chrome and ChatGPT CPU bursts in measured windows; for example A2 includes a Chrome peak around 12.7% of the whole machine alongside ChatGPT around 4.2%. Historical gravel returns also overlap downloader/ChatGPT activity. These observations correlate with variation; they do not prove causality. The substantially steadier current GPU mean and variable render CPU/frame tails justify investigating CPU scheduling and collision/publication events first. Process working sets are roughly 1.84-1.91 GiB and GPU allocation roughly 4.12-4.16 GiB in representative arms. Allocation is not physical VRAM occupancy, and these receipts do not establish thermal, clock, residency or driver-compilation causes.

The exact missing repeatability evidence is a controlled quiet-background A/A return with synchronized CPU scheduling, effective frequency and queue/wait telemetry (for example ETW/WPA), retaining the same frozen inputs and first encounters. If GPU pressure is suspected, add synchronized GPU clocks/power/utilization and residency/eviction evidence. The bounded timing budget is exhausted; no further benchmark loop was run. This external machine-state attribution is required before marking this optimization prerequisite done.

## Native GPU attribution and tree inventory

These profiles are separate 15-second, one-repetition runs. Intervals use verified start markers in the pinned engine; four resolved boundary frames per end are excluded. No dropped query frames occurred. Interior counts are forest 890, open 1,412, mineral 970 and stress 810. Repeated labels are summed within a resolved frame, absent intervals count as zero, nested totals are not added, and requesting simulation ticks are never treated as exact delayed GPU identities. The marker named FSR2 encloses the actual FSR 4.1.1 provider.

| Native interval, mean ms | Forest | Open | Mineral | Stress |
|---|---:|---:|---:|---:|
| Render Depth Pre-Pass | 4.699 | 0.932 | 1.926 | 2.375 |
| Render Opaque Pass | 2.805 | 0.805 | 0.968 | 1.658 |
| Render Motion Pass | 0.715 | 0.737 | 1.750 | 1.372 |
| Render Directional/SpotLight Shadows | 0.471 | 0.176 | 0.342 | 0.437 |
| FSR2 | 1.679 | 1.741 | 1.943 | 1.861 |
| Glow | 0.432 | 0.503 | 0.556 | 0.568 |
| Process SSIL | 0.382 | 0.320 | 0.528 | 0.462 |
| Render 3D Transparent Pass | 0.263 | 0.079 | 0.061 | 0.072 |

The forest depth, opaque and motion intervals total 8.219 ms; with shadows, 8.690 ms. This is a loose shared-pass ceiling including terrain, rocks, trees and other work, not a removable forest cost or a promised gain. Opaque and cutout geometry are not separately timed inside those passes. No native per-family draw/vertex capture was performed, so vertex execution versus cutout overdraw, bandwidth and waits remains unresolved.

A separate frozen CPU inventory at forest tick 2 groups batches by asset and LOD, conservatively tests main-view bounds, and reproduces the current shader distance/crown/residency coverage. Shadow batches are not camera-frustum rejected. It counts candidate mesh instances and vertex/index entries, not exact GPU submissions or visible/rasterized triangles. Per-asset rows are retained in [inventory.json](../artifacts/rendering_baseline_20260914/frozen/candidate/artifacts/pc_environment/rb-forest-inventory/inventory.json).

| LOD | Candidate instances | Zero-coverage candidates | Candidate vertex entries | Zero-coverage vertex entries |
|---|---:|---:|---:|---:|
| Near 0 | 210 | 165 | 6,329,149 | 4,893,119 |
| Mid 1 | 308 | 88 | 3,017,988 | 851,054 |
| Far card 2 | 14,341 | 272 | 57,364 | 1,088 |
| Shadow 5 | 397 | 309 | 842,923 | 665,636 |

These counts support an individual-selection experiment and show why a primitive count alone cannot be converted into saved milliseconds. The inventory is one camera sample, not route-wide residency or visibility acceptance.

## Ranked next experiments

Rank is provisional while the total-frame gate is blocked. Bounds below overlap; never add them. Existing terrain/snow query, animation and spatial batching gains remain unchanged. Previously rejected zero-coverage/powder shader pilots and publication-only micro-optimizations remain rejected; this task does not revive or dispatch them.

| Rank and routed task | Measured lead / confidence / removable ceiling | Overhead and visual risk | Next experiment and kill criterion |
|---|---|---|---|
| 1. [Individual tree selection](../backlog/abandoned/AA-20260914-094136-select-forest-lods-before-submission.md) | High confidence that eligible near/mid batches contain zero-coverage instances; medium confidence that pre-vertex selection is worthwhile. Shared forest geometry ceiling 8.219 ms, not all removable. | CPU selection/compaction or compute dispatch, buffer uploads and synchronization could consume savings. Preserve crown transitions, wind, silhouettes and shadows. | First obtain a bounded renderer capture separating actual instance/vertex work from cutout fill, then pilot selection under matched return controls. Kill if it does not reduce that work and GPU time beyond measured control spread, or worsens total frame/tails or visuals. |
| 2. [GPU passes](../backlog/abandoned/AA-20260912-105302-reduce-dense-scene-gpu-cost.md) | High confidence in depth 4.699, opaque 2.805, motion 0.715, reconstruction 1.679 ms. Attribution does not identify a replaceable algorithm. Ceiling is the selected pass only. | Extra buffers, dispatches and barriers; risks to depth, snow/material appearance, motion vectors and reconstruction. | Capture vertex/fill/bandwidth and wait causes in the leading pass, then one equivalent algorithm. Kill if measured net savings fail the matched gate or selected quality changes. |
| 3. [Publication/collision](../backlog/tasks/AA-20260913-141128-reduce-forest-publication-and-collision-bursts.md) | High confidence in individual event tails up to 26.602 ms; their reducible fraction is unknown. Event duration is a loose local ceiling, not an average-frame saving. | Preparation memory and cache reuse may trade load time for smaller cook/upload events; preserve collision authority and residency. | Attribute the largest native cook/upload operation and test avoiding/reusing it. Kill if only script counters improve while measured event/frame tails do not. |
| 4. [Distant stands](../backlog/tasks/AA-20260914-094136-render-distant-forest-stands.md) | Far-card inventory has only 57,364 candidate vertex entries at this camera. Fill/overdraw may still matter; confidence in large geometric savings is low. No isolated stand cost; shared 8.219 ms ceiling is very loose. | Atlas/build/streaming cost; risks to parallax, canopy gaps and seasonal silhouettes. | First isolate distant-card pixel/overdraw cost across qualified views. Kill if isolated cost cannot justify the representation change or gaps/silhouettes fail. |
| 5. [Terrain occlusion](../backlog/tasks/AA-20260914-094136-cull-scenery-behind-terrain.md) | Hidden eligible work not measured. No isolated saving; shared geometry ceiling only. | Occlusion hierarchy/queries, latency and conservative bounds; risks to ridgelines, wind-expanded trees and shadows. | Measure fully hidden eligible work and culling overhead. Kill if net saving fails the gate or any visible geometry disappears. |

## Verification, failures and reproduction

The offline auditor has focused identity, source drift, focus, endpoint, cache, pixels, missing receipt, nonfinite sample, control matching, native timestamp and integral-float run-number checks. The corrected open benchmark passed three native timing repetitions plus a separate visual and GPU-profile run. No gameplay physics/input/session or renderer implementation changed, so the physics/runtime suites are outside this validation-only milestone. Native visuals qualify the measurement cameras; they do not establish full-descent, controller feel, continuous smoothness or human comfort acceptance.

Two failed visual attempts remain explicit rejected entries: the old bare-snow assertion, and an independent mineral warmup access violation (`c0000005`, Windows Application Error 1000 / WER 1001, PID 5256, unknown module). The one permitted mineral retry passed. It produced no original timing window; the [crash receipt](../artifacts/rendering_baseline_20260914/mineral_native_crash.json) and guard logs are retained without claiming the crash was fixed. Successful captures are never timing rows.

Rebuild the detailed table without running the engine:

```powershell
python scripts/rendering_baseline_report.py --manifest artifacts/rendering_baseline_20260914/manifest.json --output artifacts/rendering_baseline_20260914/run_table.json
python -m unittest discover -s tests -p test_rendering_baseline_report.py
```

The ignored evidence root retains `run.ps1`, `sequence.ps1`, trace/camera producers, `plan.json`, `manifest.json`, exact source/engine hashes, all frozen trial directories, GPU queries, CPU events, system/guard receipts, inventory and native PNGs. `sequence.ps1` documents the actual initial/controls/followup/profiles/confirm invocations and owns the guards; do not nest it or reuse labels to overwrite evidence. Use fresh labels and requalify current source for a new experiment through the maintained [benchmark entry points](VALIDATION.md#performance-method). The report and receipt are dated evidence, not perpetual acceptance.

Raw and frozen evidence remains retained for the unresolved repeatability and native-crash findings. Only disposable task-owned inspection helpers are eligible for post-push cleanup.
