# Snow shape readability

The subsequent [soft snow treatment](SOFT_SNOW.md) retains the shape/contact
shading described here, while increasing the following sheen/glow values by
20%/10% and softening fine material detail. Values below describe this pass's
original readability baseline.

Snow keeps its bright, sparkling style while broad glare is reduced. Clear-day
filmic exposure is 1.15 (previously 1.30). Balanced/High broad sheen is
0.084/0.132 (40% lower), and highlight glow is 0.252/0.35 (30% lower). Individual
crystal intensity, density and filtering are unchanged. Low retains its existing
reflection budget. The sun direction, sky fill, tone mapper and white point keep
their existing weather/daylight behaviour. Balanced/High SSAO uses 0.20 direct
light influence with the existing 0.65 m radius; Low still disables SSAO.
The local Forward+ shader gates that influence with the AO-channel blend, so
`ssao_ao_channel_affect` is 1.0. At 0.0 the direct-light setting is inert.
The renderer uses the minimum of material AO and screen-space AO, then applies
the restrained direct-light weight; it does not multiply the two AO maps.

## Shape shading

`scripts/presentation/snow_readability.gd` reads the final immutable support
heights during the world's existing data-worker loading stage. Four symmetric
neighbours at 4 m and 12 m give two local concavity measures. Opposite slopes
cancel, so a uniformly tilted plane has no shading. Missing boundary pairs
contribute zero; the small dead zone excludes float32 elevation noise. Concave
regions darken, while convex crowns receive no bright outline.

The derived R8 image includes mipmaps and is uploaded once per loaded world.
It is presentation data, included in v15's validated scenery preparation cache;
this strength adjustment changes no cache schema or authoritative terrain data.
It uses packed heights directly without terrain-query
dictionaries or a second height copy. Preparation and texture-upload timings,
texture size and build count are available through `world.snow_readability.report()`.

The shared shader helper applies at most 13.98% linear-light luminance reduction,
using the multiplier `(0.804, 0.8698, 0.93)` for a slight cool tint. This is 40%
more local shape contrast than the initial 9.99% treatment. It fades from
80 to 160 m and follows the existing sun-altitude daylight fade to zero at night.
World-coordinate texel centres, linear filtering and mipmaps make the map agree
across chunk boundaries and temporal upscaling. No animated noise, extra light,
normal exaggeration or geometry displacement is introduced.

Large maps use bounded row workers inside that loading stage (four by default,
or the v15 loading job's allocation, capped at six).
They read the shared packed heights and produce disjoint byte arrays; joining
in row order preserves identical pixels and mipmaps. Small fixtures run directly.
No terrain analysis, thread creation or texture rebuild runs during skiing.

The world binds the same texture to terrain, terrain-following tracks, and High's
replacement powder patch. Exposed rock is excluded by the existing snow/rock
material blend. Tree-base snow skirts inherit the same mapping from their
terrain material copy. Other material users such as distant scenery and props
keep the new uniforms disabled. Quality changes and rider resets retain the
single map; loading another mountain creates a new world-owned map.

## Validation

Run the complete guarded validation with `scripts/validate_snow_readability.ps1`.
Use `tests/snow_readability_suite.gd` headlessly through `scripts/run_snow_check.ps1`
for focused geometric checks;
`--mountain` adds the validated default v14 cache fixture. Geometric checks cover
horizontal/tilted planes at mountain elevation, boundary behaviour, hollows,
convex crowns, orientation, repeatability, shared mapping and immutable heights.
Single-worker and parallel maps must match byte-for-byte, including mipmaps,
on both synthetic hollows and the entire default v14 mountain.
The golden-sunlight suite covers live quality/weather changes, binding reuse and
simulation/record identity.

`tests/snow_readability_playtest.gd` compares current materials with a frozen
original shader graph under `artifacts/snow_readability/reference/`. The source
snapshot is retained separately under `baseline/`; reference includes point only
at that frozen graph. Baseline exposure/sheen/glow/AO values are restored solely
inside this unranked harness, without changing player preferences. The same
world, camera, settings and actual solver inputs are used for both looks.
Static comparisons hide equipment spray and freeze weather particles. Motion
advances seeded particles with simulation time after presentation updates, so
screenshot/readback time cannot age the particles. Uncaptured timing retains
the normal particle clock. The initial capture exposed an uncontrolled spray
clock; corrected comparisons are retained separately under `final/`.

Visual runs use actual 3840x2160 output, Auto FSR at 75%, frame generation and
SDFGI off. Motion images are reduced to 1920x1080 only after readback for storage.
`--timing` performs uncaptured ABBA short skiing fixtures at the 120 rendered FPS
cap, recording CPU/GPU and frame p95/p99 independently of screenshot overhead.
These fixtures do not establish full-descent performance or player acceptance.

`scripts/report_snow_readability.py --visual artifacts/snow_readability/final/visual
--timing artifacts/snow_readability/final/timing --videos` builds the portable
HTML comparison gallery and paired 30 fps videos. It requires Pillow and the
existing local ffmpeg binary under `.tools/animation-video/`. Image statistics
are diagnostics, never an automatic readability grade.

## Stronger tuning (2026-09-10, v15)

The follow-up request for a little more definition raises maximum hollow
darkening from 9.99% to 13.98%, and direct SSAO influence from 0.15 to 0.20.
Exposure, sheen, glow, crystal sparkles, concavity data and fades remain the
same. The shader performs the same work with stronger coefficients. The
production changes are two material/lighting constants;
terrain geometry, generation and simulation code are unchanged. Existing v15
source validation can rebuild the scenery cache after the lighting source edit.

`tests/snow_readability_retune_playtest.gd` compares the previous balanced
treatment against this tuning on the same cached v15 Standard world. Multiplying
the new hollow strength by `1/1.4` reconstructs the previous tint exactly;
direct SSAO influence is restored to 0.15 for the before view. All other lighting
values and geometry remain shared. The forest-site helper uses the existing
packed-obstacle accessor so the harness supports current v15 data.

The focused geometry suite passes 16 checks and the lighting suite passes 50.
These include neutral uniform slopes, real hollows, unchanged heights and
simulation state, shared texture bindings, and quality/weather transitions.
Logs are under `artifacts/guarded/snow_readability_retune_geometry/` and
`snow_readability_retune_lighting/`. The new comparison harness also parses in
the geometry suite.

Fresh native evidence is in `artifacts/snow_readability/retune/visual/index.html`
and `report.json`: 19 matched still pairs covering four terrain locations,
clear/cloudy/snowfall, three sun-relative angles, tracks on all presets, and
night; plus two four-second chase/first-person motion pairs at an initial
22 m/s. Every paired camera and simulation trajectory matches, no source
changed during capture, and the run remained unranked with no engine errors.
Output was 3840x2160, internal 2880x1620, Auto FSR 4.1.1, frame generation and
SDFGI off. The existing v15 scenery cache supplied the unchanged 3.00 MiB map.

Inspected bank views show slightly stronger cool separation; open snow retains
its bright glints. Track views show no obvious added colour discontinuity.
Sampled consecutive chase frames and paired first-person views show no obvious
new contour band, but these short captures do not establish full-descent
stability or earlier edge recognition. The user's skiing acceptance is open.

Another interactive playtest remained open. This run explicitly used the
guard's concurrent visual mode (`snow_readability_retune_visual`); its loading
and frame timings are **not an isolated performance comparison**. No fresh
performance claim is made for this constant adjustment. The v14 timing table
below belongs to the original treatment, not the current tuning or generator.
Rebuild the gallery with `scripts/report_snow_readability.py --visual
artifacts/snow_readability/retune/visual --timing
artifacts/snow_readability/retune/timing --videos`.

## Initial v14 loading measurement (2026-09-10)

The default 1537x1537 R8 texture occupies 3,148,799 bytes including mipmaps
(3.00 MiB). A focused comparison on the RX 9070 / Ryzen 5 5600X PC measured
5,936.95 ms for the original serial preparation, 4,984.25 ms for typed serial
rows, 2,637.34 ms with two workers, 1,575.81 ms with four, and 1,267.01 ms with
six. Four was selected for the initial implementation; v15 now shares the
loading job's worker allocation and scenery cache (see [generation](../development/GENERATION_V15.md)).
Every result matched the same image SHA-256, including all mip levels:
`facba3a35299076ed7019efc1c069cea897311808f1d2f8985e619ac4d570bb0`.
See `artifacts/snow_readability/loading_benchmark.json` for the focused run.

This isolates texture preparation; it is not a measurement of the complete
time to ski. Remaining startup costs include the existing material/scene
construction and uploads. If the added preparation later becomes significant,
the next useful comparison is a bulk native stencil or a validated presentation
cache against this exact image checksum and end-to-end loading time; neither
is required for this pass.

## Initial v14 automated and rendered evidence (2026-09-10)

The focused geometry suite passes 18 checks, the updated golden-sunlight suite
passes 50, and the existing PC graphics suite passes 14. These cover geometry
neutrality, actual hollows, immutable mountain/obstacle data, shared bindings,
quality/weather transitions, and simulation/record state. The final focused
suite repeats the full-map serial/parallel equality check after the loading
optimization. Full solver changes were not part of this pass.

The original shader graph and its source snapshot remain unchanged in
`artifacts/snow_readability/reference/` and `baseline/`. The initial run and its
guard log remain available; `final/visual` is the corrected particle-controlled
comparison. Every reported visual/timing run checks its live source hashes at
start and finish, records engine/backend/display identity, and stays unranked.

Visual inspection is intentionally qualitative: bright areas retain crystal
glints, broad sheen is less dominant, and shallow concave areas acquire a subtle
cool separation. The isolated shape pair makes that local change easier to see
with lighting/exposure held fixed. Inspected stills show no new bright contour
halos, dirty bands or obvious colour seams at the powder replacement boundary.
The difference is small on uniform slopes and in overcast views. Contact shading
remains restrained. These observations do not measure how much earlier a rider
can identify an edge, nor establish temporal stability on a complete descent.

The corrected final run contains 44 paired still comparisons (88 images) and
eight motion pairs. Stills cover four terrain sites, clear/cloudy/snowfall,
toward/across/away sun views, all track quality presets, dawn/dusk/night, and
isolated shape/contact treatments. Motion covers chase and first-person views
in clear weather and snowfall on open and forest terrain, starting at 22 m/s.
Open clips last four seconds; forest clips end at the same tree impact at
3.267 seconds. Every paired trajectory checksum matches. Sampled consecutive
frames retain world-locked shape contrast without an obvious added flickering
band; this is a short-sequence inspection, not full-descent temporal acceptance.

The final native run used the custom Godot 4.7.2 D3D12 engine on RX 9070,
Auto FSR 4.1.1, 3840x2160 output / 2880x1620 internal, SDFGI off and frame
generation off. Uncaptured timing used the 120 rendered FPS cap and ABBA order,
with two runs per look/condition/site (8,880 frame-time samples overall).
The table reports means of the two per-run statistics, **not pooled percentiles**.

| Short fixture / look | Mean frame ms | p95 ms | p99 ms | GPU mean ms | Render CPU mean ms |
|---|---:|---:|---:|---:|---:|
| Open, clear / before | 8.749 | 10.731 | 12.578 | 7.273 | 1.987 |
| Open, clear / after | 9.032 | 10.983 | 12.955 | 7.108 | 2.123 |
| Open, snowfall / before | 9.033 | 11.619 | 14.737 | 7.070 | 2.080 |
| Open, snowfall / after | 8.941 | 10.916 | 12.637 | 6.899 | 2.093 |
| Forest, clear / before | 11.322 | 13.175 | 14.990 | 10.552 | 1.272 |
| Forest, clear / after | 11.470 | 13.322 | 15.090 | 10.656 | 1.386 |
| Forest, snowfall / before | 11.430 | 14.669 | 16.642 | 10.655 | 1.325 |
| Forest, snowfall / after | 11.528 | 14.641 | 17.159 | 10.755 | 1.354 |

The forest treatment adds about 0.10 ms GPU time in these samples. Open-slope
CPU/frame results vary in both directions across conditions; no FPS improvement
is claimed. Final open sections average about 111 rendered FPS; dense forest
sections average about 87 FPS and still miss the 90 FPS / p95 target with either
look. The snowfall forest after case also slightly exceeds the 16.7 ms p99
target. Further forest/render performance work needs longer matched descents;
this appearance pass does not establish overall PC performance acceptance.

In the final actual loading flow, shape preparation took **1,468.46 ms**, and
ImageTexture creation/submission took **0.728 ms** (not a GPU-completion fence).
Warm physical-cache reconstruction was 9.560 s; world construction was 107.421 s;
the test reached initialized gameplay in 122.758 s overall. Only the isolated
texture cost is attributed to this change. Godot reported a peak 3.805 GiB of
video allocations during timing. The guarded validation job peaked at 6.971 GiB
private allocation, with at least 3.199 GiB system RAM available in its samples.
These allocation counters are not exact physical GPU residency/working-set
measurements. The guard recorded no engine error, driver reset, or background
driver application error.

Final reports are `artifacts/snow_readability/final/visual/report.json` and
`final/timing/report.json`; guard evidence is under
`artifacts/guarded/snow_readability_final/`. Runtime source hashes matched at the
time of that initial validation. The portable gallery is `final/visual/index.html` after running
the report builder above. **The user's skiing/readability acceptance remains
open**: the captures do not prove earlier edge recognition or comfort on a
complete descent.
