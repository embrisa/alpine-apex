# Camera profiles and preview validation — 2026-09-11

The implementation follows the Connected/Race/Stable values in [Camera](CAMERA.md).
Camera source and interface changes were validated and pushed in `4e88937` and
`5a0e53f`. The world during this review includes the concurrent off-map scenery
checkpoint `06ec1d1`. The solver is model 28 at 120 Hz, using Standard v15 seed
849205174. These are separate correctness, rendered-framing, performance and
human-acceptance results.

## Automated correctness

All workloads ran serially through `scripts/run_guarded.ps1`, with isolated
preferences and unranked sessions. All 3,164 parameterized checks passed:

| Suite | Passed checks |
| --- | ---: |
| Camera profiles | 1,962 |
| Camera framing, stability and look | 766 |
| Runtime | 187 |
| Interface | 114 |
| Physics | 56 |
| Menu camera | 20 |
| Foliage sight | 59 |

Import and main-script parsing also passed. Coverage includes progression
endpoints and intermediate speeds, reversed/fixed endpoints, finite values,
absolute tilt, per-view independence, individual effect strengths, recentering,
terrain/geology clearance, and response at 30/60/120/240 FPS. The controlled
bump/contact/airtime/landing fixture recorded 0.0 degrees of optical pitch
excursion. This does not mean the camera position is motionless.

Profile checks cover immutable built-ins, Custom working copies, named-preset
CRUD, explicit replacement, reset behavior, malformed data, isolated save/load
and scene-reload snapshots. Runtime/interface checks cover preview ownership,
stationary simulation/session state, retained riding view, focus loss, loading,
restart, keyboard and synthetic controller navigation, scrolling, restored
instruments and the menu-only controls footer. Synthetic input is not physical
controller acceptance.

Guard logs are under `artifacts/guarded/camera_v2_*`. Detailed camera results
are in `artifacts/camera_upgrade/camera_results.json`.

## Native rendered review

Native captures use the custom Godot 4.7.2 DX12 engine and RX 9070, High,
Auto FSR at 75%, frame generation and SDFGI off. The capture harness advances
controlled frames and includes readback overhead; its displayed FPS is not
gameplay performance evidence.

The initial 1280×720 settings/preview review produced 14 captures without
failures in `artifacts/pc_environment/camera_v2_720`. Expandable groups,
slider focus/scrolling, the preview drawer and restored normal settings layout
were inspected at this resolution. A further 68 captures in
`artifacts/pc_environment/camera_v2_720_presets` passed without failures and cover
all presets, both views and upper/steep/forest terrain at 0/120/200 km/h in
addition to the settings lifecycle. The skier, snow and forward terrain remain
readable in the inspected native 720p preset samples.

The 3840×2160 matrix produced 182 captures without failures in
`artifacts/pc_environment/camera_v2_4k`. All three presets and both views cover
upper terrain, steep slopes and forest at 0, 60, 120, 160 and 200 km/h.
Separate real-solver sequences cover carving/braking, takeoff/landing and steep
skiing, including first-person takeoff/landing. Twelve three-second clips retain
180 frames each at 60 presentation frames/second and 120 simulation ticks/second.
Separate synthetic 8 Hz bump sequences are explicitly labeled.

A further 12 native 4K captures cover the near-flat summit (measured slope
7.999 degrees), all presets and both views at 0/200 km/h, in
`artifacts/pc_environment/camera_v2_flat`; no capture checks failed.

Reviewed frame sequences keep the chase skier and skis visible and show nearby
snow plus downhill terrain. Connected holds a larger skier than Race at speed;
Stable holds fixed lens/boom endpoints. Near-flat Connected framing at rest is
deliberately dominated by nearby snow, with less distant scenery than the steep
descent views. First-person review hides the skier body and retains a usable
forward terrain view. Sampled moving takeoff/landing and carve/brake frames show
the intended stable optical aim; subjective speed, comfort and controller feel
still require skiing by a person.

Native originals and JSON metadata remain in the labeled directories. Review
contact sheets and 1080p/60 FPS MP4s are in `artifacts/camera_v2/review`, including
`connected_turn_brake.mp4`, `connected_jump_land.mp4`, and corresponding Race,
Stable and first-person clips. The MP4s are encoded from the captured moving
frames; frozen fixtures are not presented as motion evidence.

## Matched performance method

The before/after comparison uses the same current world, app, input trace and
settings, changing only the camera implementation. The old camera and old
settings are frozen in ignored `artifacts/camera_v2/baseline_*.gd`; the removed
workbench response is replaced by its old default 7.5/s in that fixture. This is
not a benchmark of two complete historical checkouts.

Both cameras use 60-degree vertical FoV, a 3.5 m boom and height, -45-degree
absolute optical pitch, 75% vertical smoothing and no optional motion. This
matches the Stable view so geometry and effects do not dominate the comparison.
The frozen old camera's geometry-derived pitch is offset to the same -45 degrees.

The successful input trace was replayed against current source receipts before
timing. Its only changed core receipts are the camera input sampling additions
and removal of camera-only workbench fields. All 35,669 ticks reproduced the
exact successful finish at `(1093.60192871094, 2375.044921875, -2631.83569335938)`.
The simulated descent is 297.241667 seconds. The refreshed trace and proof are
`artifacts/camera_v2/descent_input.json` and `trace_refresh.json`; the original
trace was left untouched.

Measurements use the actual 3840×2160 output, High, Auto FSR 75%, 120 rendered
FPS cap, frame generation and SDFGI off, with 240 warmup frames and no capture
readbacks inside the timing interval. Rendered frame distributions, CPU/GPU
render time, camera CPU scope, per-section results and memory are retained in
each production report and raw frame-sample file. No other validation workload
runs concurrently.

## Matched performance results

Both descents completed with the exact same finish, no engine errors, and no
changed sources among 906 audited code/resource files and benchmark inputs.
The camera harness's initial historical-settings assignment was corrected before
these successful runs; the stopped pre-measurement attempt is retained in the
guard's history directory. No production camera changes followed visual review.

The measured PC is Ryzen 5 5600X, RX 9070, 16 GiB installed RAM, AMD driver
32.0.31041.1004. Actual output is 3840×2160 fullscreen, internal resolution
2880×1620, FSR 4.1.1, High, cap 120, SDFGI off. Frame generation is disabled and
both reports record **zero generated frames**. All FPS below is rendered FPS.

| Complete descent metric | Frozen old camera | New camera |
| --- | ---: | ---: |
| Measured rendered frames | 27,207 | 26,086 |
| Wall duration | 297.250 s | 297.248 s |
| Mean frame time / average FPS | 10.925 ms / 91.53 | 11.394 ms / 87.76 |
| Median frame time / median FPS | 9.881 ms / 101.20 | 10.207 ms / 97.97 |
| Frame p95 / p99 | 15.890 / 19.514 ms | 16.699 / 24.119 ms |
| Slowest 1% average FPS | 39.12 | 34.79 |
| Render CPU mean / p95 / p99 | 1.444 / 2.034 / 2.386 ms | 1.544 / 2.327 / 2.760 ms |
| GPU mean / p95 / p99 | 8.564 / 10.994 / 12.117 ms | 8.856 / 11.144 / 12.194 ms |
| Camera CPU mean / p95 / p99 | 0.084 / 0.106 / 0.139 ms | 0.095 / 0.124 / 0.161 ms |
| Camera mean as share of mean frame | 0.77% | 0.83% |
| Peak Godot-reported video memory | 3,707,816,864 B | 3,707,816,864 B |
| Peak Godot static memory in descent | 1,178,303,643 B | 1,177,969,919 B |
| Guarded process-tree peak private bytes, including loading | 5,955,854,336 B | 5,953,138,688 B |
| Guarded process-tree peak resident bytes, including loading | 1,978,269,696 B | 1,958,555,648 B |

This pair measured a 4.1% lower average rendered FPS with the new camera and
0.0105 ms more mean camera CPU work. Frame p99 increased by 4.605 ms. The larger
frame-time change includes variation outside the camera scope; GPU and render
CPU timings also changed. One sequential pair does not establish how much of
that whole-frame difference is repeatable or caused by the camera implementation.
It must not be reported as a performance improvement or a passed 90–120 FPS
acceptance test. The old camera already missed that target in its slow frames;
the new run averaged below 90 and retained substantial tails.

The largest section change is the mineral region: mean frame time
12.088 → 13.943 ms, p95 16.477 → 22.506 ms. The forest section was
10.346 → 10.592 ms mean and 15.465 → 15.547 ms p95. The camera remains a small
measured CPU scope. Remaining performance investigation should distinguish
GPU work and the larger simulation/pose/effects scopes from camera evaluation;
these scopes have different tick/frame cadences and should not simply be added.
No simulation, animation or scenery optimization was folded into camera tuning.

This is fixed Stable framing in the current app, not an absolute benchmark of
Connected's changing framing or the entire pre-feature app. Scenery is frozen at
the reviewed `06ec1d1` asset for both runs; later scenery reference corrections
require their own current acceptance measurements. This comparison does not
keep an additional old scenery world resident. Godot video/static counters and
the whole-invocation process-tree counters measure different allocations and
intervals; neither should be labeled total dedicated physical VRAM usage.

Raw reports are
`artifacts/pc_environment/camera_v2_matched_before/production.json` and
`artifacts/pc_environment/camera_v2_matched_after/production.json`, with
`frame_samples_1.json` in each directory. The validated comparison is
`artifacts/camera_v2/performance_comparison.json`; environment and before/after
source receipts are adjacent. Guard telemetry and command arguments are in the
corresponding `artifacts/guarded/camera_v2_matched_*` directories.

## Human acceptance

Physical controller feel, perceived speed, comfort over a complete run, and the
user's preferred framing remain unverified. The preview is explicitly stationary
framing; use Resume skiing to assess motion. Automated checks and image review
do not establish these subjective results.
