# Alpine wilderness and summit return

**Current scenery: [presentation v2](OFFMAP_V2.md).** The complete off-map apron
and panorama now share a connected ridge network and blended materials. The
landscape implementation and measurements below describe the earlier v1;
summit-return behavior is unchanged by the v2 presentation update.

Generated summit mountains have an unreachable, seeded alpine panorama extending
18 km from the center. Free skiing and racing share a 2,850 m summit-return
boundary. These are presentation and session rules: no ski forces, physical
heights, obstacles, snow depth, or generator selection are changed here.

## Landscape

`wilderness_data.gd` arranges 36 elongated peaks across three ridge/valley bands,
with broad snow/rock colors and low-elevation forest patches. It uses packed
mesh arrays, not another high-resolution height image. `alpine_wilderness.gd`
renders 24 culled batches with one opaque Lambert shader, vertex colors, and the
existing sun, moon and fog. Weather adjusts direct-light strength. There are no
collision shapes, individual distant trees, shadow casters or GI contributors.

All 1,024 inner-edge samples match the existing 32 m apron perimeter. Fine seam
triangles transition to more evenly spaced radial geometry. Snow color continues
across the join before blending into lower valley colors. Existing mountain data
and its scenery descriptor/version remain unchanged; the panorama has its own
version and separately salted scenery seed.

| Preset | Additional triangles | Batches | Outer radius |
| --- | ---: | ---: | ---: |
| Low | 19,200 | 24 | 18 km |
| Balanced | 37,632 | 24 | 18 km |
| High | 74,240 | 24 | 18 km |

Meshes are generated at world load and rebuilt only when quality changes. High
construction was about 1.4–1.7 seconds in development runs. Per-frame work updates
one lighting uniform. Gameplay/survey far clipping is 32 km; shadow distances
retain their existing quality budgets. The internal `--wilderness=off` comparison
option omits the added meshes but retains the physical mountain and scenery apron.
Godot's [distant-material guidance](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html#use-simpler-materials-at-a-distance-to-improve-performance)
explains the reason for using a separate, cheaper distant material.

## Zone and return lifecycle

`mountain_zone.gd` is Node independent and supplies containment, signed distance,
and swept exit fractions in metres. The disk is centered on the summit spawn
and extends indefinitely in Y. It applies to generated summit mountains;
laboratory and archived non-summit fixtures retain their existing bounds.

Within the final 150 m the HUD shows **Summit return — 120 m**. There are no
boundary markers during skiing. Crossing freezes movement, fades out for 0.2 s,
resets at the summit, then fades in for 0.2 s. Reduced motion skips the fade.
Held tuck/Enter/gamepad drop-in controls must return to neutral before launching.

The existing restart resets velocity, impact reserve, timing, recording, ragdoll,
camera/pose history, tracks, particles and pending jump input. Camera preference,
graphics, weather and daylight state are retained. Pause/focus loss during a fade
leaves the returned rider paused. Explicit restart, world changes and destruction
cancel the old transition. Crash ragdolls are checked using their physical hip
position even though the ski simulation is inactive.

Race schema **2** starts fresh libraries at `user://races_v2/` and
`user://race_records_v2/`. Schema-1 imports are rejected; old files are neither
loaded nor migrated. Record identities include zone rules version **1**. Race
endpoints must be at least 25 m inside the disk, keeping the entire 12 m finish
area inside it. Creation, import and launch use the same validation. Only the
race-authoring survey displays the boundary outline.

An unfinished race crossing the line is aborted without saving a result. Main
compares finish and zone crossing fractions before persistence: a strictly
earlier finish saves its fractional result; a tie or later finish loses to the
boundary. A later rectangular safety-boundary failure cannot erase an earlier
finish. Every boundary return leaves the race and stages summit free skiing.
Manual R during an ordinary race still retries its authored start. Autoplay
measurements terminate at the line without looping or writing player records.

## Reproduction and evidence

Windows commands use `./godotw.ps1`, with the argument separator quoted. The
`./godotw` wrapper provides the corresponding workflow on other platforms.

```powershell
./godotw.ps1 --headless --script tests/mountain_zone_suite.gd
./godotw.ps1 --headless --script tests/wilderness_suite.gd
./godotw.ps1 --headless --script tests/wilderness_fingerprint_suite.gd
./godotw.ps1 --headless --script tests/summit_return_suite.gd '--' --graphics-quality=low
./godotw.ps1 --script tests/wilderness_playtest.gd '--' --views --benchmark-label=wilderness_final --benchmark-resolution=3840x2160 --graphics-quality=high --render-scale=0.75 --upscaler=fsr2 --fps-limit=120 --terrain-gi=off
./scripts/benchmark_pc.ps1 -Label wilderness_off -Wilderness off -ThirdPerson
./scripts/benchmark_pc.ps1 -Label wilderness_on -Wilderness on -ThirdPerson
./scripts/benchmark_pc.ps1 -Label wilderness_summit -WildernessSummit -ThirdPerson
```

Automated logs are in `artifacts/wilderness/`. Native captures/measurements are in
`artifacts/pc_environment/wilderness_*`. The summit comparison uses off/on/on/off
blocks on three bearings, 120 warmup frames and 360 measured frames per block,
without screenshot readback in measurement windows. Descents record physical
fingerprints, actual pixels, CPU/GPU timing, frame percentiles, draw calls,
memory, loading time and source hashes.

Targets: additional median GPU cost <=0.5 ms and p95/p99 frame-time regression
<=5%, alongside the project's 90–120 FPS policy. Automated rules, rendered
inspection, measured performance and human skiing acceptance are distinct.
Physical keyboard/gamepad feel and subjective panorama acceptance remain user
playtest items. See the acceptance results below for measured limitations.

## Acceptance — 2026-09-07

### Automated

The required physics (56), runtime (93), race (51), competitive (64), graphics
(28), rider lifecycle (17), PC graphics (14), mountain zone (26), summit return
(27), wilderness geometry (7) and archived fingerprints (13) suites pass:
**396/396 checks**. The lifecycle
suite now explicitly selects its laboratory fixture, as the other laboratory
regressions already do. Player race/benchmark records are isolated from these
tests. Native device/rendering acceptance is not inferred from headless results.

Fresh v1–v8 generation matches every frozen height and obstacle checksum. For
each summit generator, building the backdrop also leaves the physical height
arrays, obstacle arrays and real apron image byte-for-byte unchanged. Results
are in `artifacts/wilderness/fingerprints.json`. The default v10 native on/off
runs both retain height fingerprint
`272e3210c85c78684fdd7a07194a0e196460c57620158b4d6263257ee48bccf2`
and obstacle fingerprint
`06b79834016e70c68e99da47d526889332ec3f190024c07f06b86ede2b6cecdf`.

### Rendered

`artifacts/pc_environment/wilderness_final/wilderness.json` indexes **46 captures
at actual 3840×2160**, High, 75% FSR2 and SDFGI off. Review covered six summit
bearings, upper/middle/lower positions in chase and first person, clear daylight,
sunset and snowfall, plus moonlight, each geometry preset, the return warning,
fade, summit reset and authoring outline. The reviewed views have no open seam
or far-plane clipping. Existing haze softens the far layers; sunset/moonlight
colors follow the rest of the world. Close inspection reveals intentionally
coarse facets on the distant slopes. The existing square apron still determines
the near landscape's shape, although the geometric join is continuous.

The screenshot HUD's FPS counter includes synchronous image readback and is not
a performance result. Panorama comparisons are `summit_backdrop_off.png` and
`summit_backdrop_on.png`; the transition is captured in `return_*.png`.

### Measured performance

Measured on the Ryzen 5 5600X / RX 9070 / 16 GB system, Godot 4.7.2 D3D12,
actual **3840×2160** output, **2880×1620** internal pixels, High, 75% FSR2,
120 FPS cap and SDFGI off. Screenshot readback is outside timing windows.

The strongest cost comparison is the same-process summit **off/on/on/off** run
on three bearings, with 2,160 measured frames per state. Source hashes stayed
unchanged; the only other Godot process sample was at startup, before loading
and warmup. Pooled median GPU time rose **5.154 → 5.573 ms**, an added
**0.419 ms**, within the **0.5 ms** budget. Frame p95 was **8.418 → 8.403 ms**
and p99 **8.609 → 8.545 ms**: neither regressed beyond the **5%** budget.
Median rendering CPU was **0.802 → 0.816 ms**; median draw calls **306 → 315**.
Average FPS was **119.13 → 119.38**. Small apparent improvements reflect timing
variation and the frame cap, not a claimed speedup from adding scenery.

The complete face-0 chase descents used the same 50,976 physics ticks, took
424.8 simulated seconds and reached the same 80.92 km/h peak. The repeat baseline
and enabled run measured:

| Metric | Backdrop off | Backdrop on |
| --- | ---: | ---: |
| Average FPS | 118.91 | 119.25 |
| Frame p95 / p99, ms | 9.057 / 10.584 | 8.867 / 9.614 |
| Median GPU, ms | 6.733 | 6.709 |
| Median rendering CPU, ms | 1.058 | 0.932 |
| Median draw calls | 364 | 374 |
| Peak reported video memory, MiB | 3,324.20 | 3,328.76 |
| Peak process working set, MiB | 1,130.46 | 1,118.68 |
| Peak process private bytes, MiB | 4,958.56 | 4,959.94 |
| World build, seconds | 10.175 | 12.030 |

The panorama itself took **1.480 seconds** to build on High. Peak reported
video memory increased by **4.56 MiB** between those descents. Complete memory,
loading, CPU/GPU distributions and source/process audits are retained in
`artifacts/wilderness/performance.json` and each run's `system.json`.

The first `wilderness_off` run is diagnostic only: loaded asset source changed
and other Godot work overlapped it. Its replacement, `wilderness_off_clean`,
retained the loaded gameplay/render sources, but background headless imports
still affected CPU/frame tails; new flavor-asset files were not referenced by
this scene. The full-descent negative GPU delta and lower enabled frame tails
therefore do not establish a speedup. The stable summit comparison supplies the
isolated marginal-cost evidence. Individual slow frames remain: the enabled
descent's slowest-1%-mean is **80.28 FPS**, despite its 119.25 FPS average and
104.02 FPS at the p99 frame time. This does not certify a 90 FPS floor.

Both relative budgets pass in the pooled summit comparison, so no additional
geometry reduction was needed. Performance acceptance is for these measured
views/settings; user skiing and a guaranteed frame-time floor remain separate.

### User skiing

Physical keyboard/gamepad play, subjective appearance and fade comfort still
need the user's skiing acceptance. Automated input proves the release gate and
repeatable lifecycle behavior, not human control feel.
