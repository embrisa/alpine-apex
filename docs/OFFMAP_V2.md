# Alpine wilderness presentation v2

The complete off-map view uses a shared seeded ridge network, extending from
the decorative apron to an 18 km horizon. Fifty-four connected ridge segments
form unequal summits, saddles and descending spurs across three distance bands.
Broad shoulders blend the existing mountain into these valleys without the
abrupt shelf produced by a short geometry transition.

## Terrain and materials

The physical support grid and its 192 m decorative collar retain their original
heights. Geometry blends outside that collar over roughly 2.3 km with irregular
widths; material blending completes earlier, before the old apron perimeter.
Both renderers sample identical positions, 32 m normal stencils and snow/forest/
stone/concavity masks at their shared 1,024 vertices. Physical-edge fan triangles
retain the existing exact 4 m support positions and render normals.

An apron-specific shader retains the full terrain material next to the protected
boundary and blends into the same cheap material as the panorama. The distant
branch uses one mipmapped existing rock-albedo texture, interpolated biome masks,
opaque Lambert lighting and existing sun/moon/ambient/fog. Steep slopes expose
slate-colored stone, sheltered slopes hold snow, and lower valleys receive forest
coverage. Fine breakup fades with distance. No distant individual trees, new
volumetrics, collision, shadow casters or GI contributors are introduced.

The main terrain's shader path is unchanged: apron branches compile only with
`ALPINE_OFFMAP`. Noon direction, weather settings, physics, race/replay identity,
terrain images, contact material maps and summit-return rules are preserved.
Only independent scenery presentation `VERSION` advances from 1 to 2.

## Construction and performance controls

| Preset | Outer triangles | Outer batches | Apron triangles on default v11 |
| --- | ---: | ---: | ---: |
| Low | 19,200 | 24 | 64,256 |
| Balanced | 37,632 | 24 | 64,256 |
| High | 74,240 | 24 | 64,256 |

The 20k/40k/80k outer ceilings, apron triangle count and 32 km far plane remain.
Spatial bins limit ridge evaluations. Canonical sample caches make joins agree
and avoid duplicate construction work; caches are released after upload.
Normal staged loading yields between apron chunks and each outer batch. Quality
changes rebuild only the panorama mesh and adjust material detail. Ordinary
frames update lighting uniforms without rebuilding geometry.

## Reproduction

Run only one native benchmark at a time. The benchmark records actual pixels,
active cap, source hashes, other engine processes and system/process memory.
Keep unrelated concurrent source edits in the audit rather than discarding them.

```powershell
./godotw.ps1 --headless --script tests/offmap_geometry_suite.gd
./godotw.ps1 --headless --script tests/wilderness_suite.gd
./godotw.ps1 --headless --script tests/wilderness_fingerprint_suite.gd
./scripts/benchmark_pc.ps1 -Label offmap_v2_abba_final -WildernessSummit -ThirdPerson
./scripts/benchmark_pc.ps1 -Label offmap_v2_descents -OffmapPaired -ThirdPerson
./scripts/benchmark_pc.ps1 -Label offmap_v2_before_clear -OffmapBaseline -ThirdPerson
./scripts/benchmark_pc.ps1 -Label offmap_v2_after_clear -OffmapComparison -ThirdPerson
./scripts/benchmark_pc.ps1 -Label offmap_v2_before_snowfall -OffmapBaseline -ThirdPerson -Weather snowfall
./scripts/benchmark_pc.ps1 -Label offmap_v2_after_snowfall -OffmapComparison -ThirdPerson -Weather snowfall
./godotw.ps1 --script tests/wilderness_playtest.gd '--' --views --benchmark-label=offmap_v2_final --benchmark-resolution=3840x2160 --graphics-quality=high --render-scale=0.75 --upscaler=fsr2 --fps-limit=120 --terrain-gi=off
./godotw.ps1 --script tests/offmap_motion.gd '--' --views --benchmark-label=offmap_v2_motion --benchmark-resolution=3840x2160 --graphics-quality=high --render-scale=0.75 --upscaler=fsr2 --fps-limit=120 --terrain-gi=off
```

The frozen renderer in `tests/fixtures/offmap_v1` is a test-only reference. ABBA
switches the complete apron and panorama in one process, on three summit bearings
and three lower viewpoints. Each block warms for 120 frames, then measures 360
without readback. The inherited capture fixture's 30 FPS cap is explicitly
replaced by the requested cap before timing. Both states retain the same physical
mountain and world. Descent baseline mode also swaps both decorative renderers.
The paired descent command runs clear and snowfall comparisons inside one loaded
world and records the actual loaded simulation source hash. Both scenery versions
remain resident in that controlled comparison; its memory figure is the combined
validation footprint, not an isolated shipped-renderer memory delta.

Acceptance allows at most +0.5 ms median GPU cost and 5% p95/p99 regression against
the current-renderer baseline. The independent project targets remain p95 <=11.1 ms
and p99 <=16.7 ms, at 4K output, High, 75% FSR2 and SDFGI off. Captures and moving
clips are visual evidence; their FPS includes readback and is not benchmark data.

## Acceptance evidence

The current run's machine-readable results and regression logs are under
`artifacts/offmap_v2`; native views and timing audits are under
`artifacts/pc_environment/offmap_v2_*`. Automated, rendered and measured results
are recorded separately in the final report. User skiing and subjective landscape
approval remain user acceptance items.

### Isolated fixed-view performance, 2026-09-08

The final `offmap_v2_abba_final` run used the target Ryzen 5 5600X / RX 9070,
3840×2160 output, High, 75% FSR2, 120 FPS cap and SDFGI off. It recorded 4,320
timed samples per scenery version across three summit and three lower bearings.
Both the requested cap and actual pixels were asserted before timing. The system
audit recorded **zero other Godot processes and zero changed source files**.

| Complete scenery | Median GPU ms | Median render CPU ms | Frame p95 ms | Frame p99 ms | Mean draw calls |
| --- | ---: | ---: | ---: | ---: | ---: |
| Frozen current v1 | 5.274 | 0.583 | 8.388 | 8.571 | 191.7 |
| Upgraded v2 | 5.188 | 0.582 | 8.385 | 8.542 | 192.0 |

Median GPU cost changed by **−0.086 ms**. The relative allowance and project
frame-percentile targets pass for these fixed views. This is not a substitute
for the separate full-descent results. Earlier `offmap_v2_abba_concurrent` and
`offmap_v2_descents_interrupted` runs are retained as diagnostic artifacts and
excluded from final acceptance because another validation process overlapped.

The cheaper distant material follows the measured-material guidance in
[Godot's visibility-range documentation](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html#use-simpler-materials-at-a-distance-to-improve-performance).

### Full descents on the target PC

`offmap_v2_descents` completed four full descents at the same target settings.
Every trial finished without a crash in **350.3083 seconds**, with an identical
peak speed of 88.429 km/h and the same loaded v16 simulation hash, terrain and
obstacle fingerprints. The v16 skier work was supplied by the concurrent skier
task; this scenery change does not modify it. Each trial warmed for 420 frames
in total before recording approximately 42,000 frame samples. Construction and
finish-screenshot readback are outside the timing windows.

| Weather / scenery | Median GPU ms | Median render CPU ms | Median physics µs | Frame p95 ms | Frame p99 ms | Mean draw calls |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Clear / v1 | 6.625 | 0.827 | 440 | 9.173 | 9.528 | 373.5 |
| Clear / v2 | 6.623 | 0.823 | 437 | 9.149 | 9.532 | 373.9 |
| Snowfall / v1 | 6.613 | 0.799 | 430 | 9.139 | 9.462 | 374.5 |
| Snowfall / v2 | 6.613 | 0.799 | 430 | 9.144 | 9.466 | 374.9 |

Both weather comparisons pass **+0.5 ms median GPU / +5% p95/p99**, and both
upgraded descents pass **p95 ≤11.1 ms / p99 ≤16.7 ms**. Clear p99 changes by
0.042%; snowfall p95/p99 change by 0.055%/0.042%. The largest individual-view
p99 change in the fixed-view ABBA blocks is 0.8%, also within allowance.

These percentile passes do not mean every frame meets the target. The clear
baseline and upgrade contain isolated maximum frames of 62.1 and 67.4 ms;
baseline slowest-1% mean is 11.63 ms (86 FPS), versus 10.73 ms (93 FPS) upgraded.
Snowfall maximum frames are 22.1 and 42.3 ms. Hitches occur in both versions;
these measurements do not establish their cause or eliminate every isolated spike.

The whole paired-validation process peaked at 1.32 GiB working set, 6.57 GiB
private allocation, 5.30 GiB driver-reported dedicated GPU memory and 0.30 GiB
shared GPU memory. Minimum free system RAM remained 6.18 GiB. Godot reported
5.16 GiB peak video resources. These include both renderer versions resident,
so they are a validation footprint rather than a shipped-memory delta.

The timed run's world construction took 28.26 seconds, including staged loading;
the upgraded apron and panorama portions took 0.690 and 1.559 seconds. The fresh
before/after native view runs observed approximately 25.9 and 24.0 seconds of
world construction. Those individual startup observations are not a controlled
loading-speed comparison. Geometry build times and hashes are included in each
native report.

The full-descent audit has zero changed source files and zero competing engine
processes. Its first raw sample briefly labels the run's own child PID 27044 as
"other" while the console launcher is still being resolved. The report retains
that raw sample and excludes the run's observed engine IDs when counting actual
competitors. No concurrent or interrupted timing run is used for acceptance.

### Automated checks

**579 checks pass across 13 suites**, with zero final failures:
`offmap_geometry_suite`, `wilderness_suite`, `wilderness_fingerprint_suite`,
`physics_suite`, `runtime_suite`, `graphics_suite`, `pc_graphics_suite`,
`golden_sunlight_suite`, `scenery_loading_suite`, `mountain_suite`,
`generated_mountain_suite`, `mountain_library_suite` and `interface_suite`.

The checks cover frozen generator fingerprints v1–v11; deterministic presentation
seeds; default seed 849205174 and additional seed 638201943; unchanged height,
obstacle, contact-material and stored environment arrays; all 1,024 apron joins;
duplicate vertices/normals across every mesh boundary; exact physical stitches;
the protected collar; all quality budgets and switches; released sample caches;
staged loading; and absence of scenery shadows/GI/collision.

Initial physics/runtime results overlapped the concurrent skier implementation.
Both were rerun on its stable v16 sources and pass. A stale generated-mountain
test expected bare seeds to choose v10; its assertion now follows
`Definition.CURRENT_VERSION`, and all 100 checks pass. Initial logs are retained
with `.log.initial` suffixes rather than replacing that history silently.

### Rendered evidence and user acceptance

The local gallery is `artifacts/offmap_v2/index.html`, generated by
`scripts/report_offmap.py`; `report.json` contains the complete measurements,
budgets, audit classification and regression results. The script exits with a
failure if relative performance, automated checks, timing isolation, baseline
provenance or the expected capture set is incomplete or fails.

There are **46 matched 4K still pairs** and **32 native camera clips**, presented
as 16 before/after animated pairs with 24 frames each. The set covers six summit
bearings, lower chase/first-person views, daylight, dusk, snowfall, night and all
three presets. Return-boundary and race-zone stills remain included. The fresh
pre-edit stills retain the skier presentation present at capture time; the paired
camera tours use one current loaded world and switch only the scenery.

Inspection of the matched stills and sampled motion frames found continuous
joins, more varied connected silhouettes and clearer valley depth, with no open
cracks, new square off-map material borders or obvious new off-map texture
stretching in those views. Low retains visibly coarser distant geometry. All
860 source images were verified as 3840×2160; all 16 animated pairs contain the
expected 24 frames. Detailed observations are in `visual_review.json`.

The camera tours are sampled visual evidence with screenshot overhead. They do
not measure gameplay frame rate or substitute for a human skiing review. User
skiing acceptance and subjective landscape approval remain pending.
