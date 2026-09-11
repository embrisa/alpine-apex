# Technical woodland and mineral density v13

Default and bare/random seeds now select generator v13, default seed 849205174.
Explicit v12 recipes still reconstruct v12. There is no save migration or recipe
schema change; v13 obstacle fingerprints separate new races and records.

V13 retains the complete v12 foundation, mineral foundation stamps, snow passes
and contact-material field. New minerals are seated on the finished support grid;
they cannot stamp terrain or repaint snow. Both the height and exposure hashes
must match an independently reconstructed v12 mountain with the same seed.

## Placement

Sixteen terrain-selected woodland bodies per face spread trees across four
elevation tiers and four lateral regions. Warped margins, local glades, winding
openings and the natural treeline remain. 4.8 m woodland and 4.5 m scatter candidate grids retain the 4.2 m
minimum trunk spacing. A static ecology index bounds stand/margin queries, and
a separate 6 m placement index bounds trunk-to-trunk clearance work.
Trees keep back from nearby steep rock edges, and local winding openings extend
through the larger woodland margins. These terrain/ecology rules preserve narrow
connections without consulting the test route graph or reserving racing lines.
A separate deterministic scatter stream adds isolated trees and loose groups
between the woodland bodies, with broad noise-thinned openings and the same
treeline, support, rock and drop restrictions.
An independent deterministic thinning stream caps accepted trees at 200,000,
without truncating a particular face or elevation when the population exceeds it.

Separate deterministic streams add debris pockets and isolated decision points
across the upper and middle slopes. The added candidate mix emphasizes medium
stones and includes large erratics/outcrops; all accepted rocks remain solid.
Only existing compact fragments populate debris. New rocks reject invisible or
unsupported seating, protected local snow openings and intended drop envelopes.
Trees avoid minerals and the same drop approaches and landings.

The default seed generates 200,000 trees and 16,022 minerals, including 102,391
scattered trees between woodland bodies. Actual counts, woodland/scatter split,
size categories, altitude bands and occupied
48 m cells are recorded in `artifacts/alpine_v13/survey_<seed>.json`.

## Rendering and collision

Distant trees use shared 192 m regional impostor batches. Detailed geometry and
stable shadow proxies use a camera-local set of 32 m regions. Region uploads are
limited to three per frame, prepared beyond the 64 m High detail distance, and
retired with distance hysteresis. Shader LOD selects each tree individually;
a small residency texture retains distant silhouettes during camera teleports
until local geometry uploads. Collision never depends on rendering residency.
Fully hidden per-tree LODs collapse their triangles before rasterization and
skip branch bending, wind and cloud sampling. Visible transition coverage and
the original v12 shader path are unchanged.

Living conifers use authored near/middle sprays and dedicated static shadow
geometry from `scripts/art/build_tree_collection.py`. The tree collection manifest
records source hashes, crown bounds and texture identity. Detail distance is
measured from each scaled crown; the 64 m High threshold and maximum visibility
stay unchanged. Automatic density derivatives have been removed. See
[Tree collection](TREE_COLLECTION.md) for the current build and measurements.

On High, cliff and huge-boulder textures use their existing Balanced maps at a
distance. Their High maps load within 280 m of a formation's bounds and retire
beyond 420 m, with at most two shared material updates per frame. This bounds the
memory cost of the expanded macro library without changing its physical shapes.
Other minerals retain their preset textures; v12 rendering remains unchanged.

All trunks retain exact footprint seating. V13 omits the full-world cosmetic
snow mounds formerly baked around every trunk; the authoritative snow surface
and root burial provide ground contact. Existing v12 presentation remains on its
original path. Low/Balanced/High retain identical physical populations.

Crash preparation queries the existing frozen obstacle grid and retains resident
IDs for retirement after teleports. Activation at 175 m, retirement beyond 240 m,
trunk dimensions, collision layers and material metadata are unchanged. No
landing, absorption, skier pose or force-model changes belong to this update.

## Reproduction and acceptance

Run engine workloads sequentially through `scripts/run_guarded.ps1`, leaving other
workloads/applications alone. PowerShell game arguments use the quoted `'--'`
separator.

### Fast test setup

The full default mountain is already saved in
`user://mountain_bake_cache_v13/default.bin` (about 66 MiB for 200,000 trees and
16,022 minerals). On this PC, `user://` resolves to
`C:/Users/hp/AppData/Roaming/Godot/app_userdata/Alpine Apex/`. Local agents using
the same compatible world sources share this cache. The separate `recent.bin`
slot stores only the most recently used non-default seed; changing random seeds
can replace that slot without evicting the default map.

Routine full-mountain tests should call the cache-aware factory:

```gdscript
const Definition = preload("res://scripts/world/mountain_definition.gd")
var field = Definition.generate(849205174, 13)
# field.cache_hit and field.generation_ms distinguish reload from a cold bake.
```

The native playtest, v13 descent suite and recorded-input fixture already use
this path or `mountain_cache_v13.gd.generate(849205174)`. Last measured warm
reconstruction was about 8–9 seconds, versus 171–230 seconds for cold generation.
Direct `alpine_massif_v13.gd.new(seed)` bypasses caching, and the v13 generation
suite's `--repeat` explicitly performs an independent cold bake. Reserve those
for generation/determinism validation, not unrelated skiing or presentation work.

The cache validates its payload and the engine plus generator, support-field,
geology and mineral source hashes. Relevant changes require regeneration; never
bypass validation to make a stale bake appear current. Ordinary skier simulation,
animation and shader edits are outside that cache key. Separate checkouts with
different world sources can invalidate each other's shared default slot.

This saves map generation, not GPU scene construction. The measured native
world-building phase still took roughly 56–78 seconds. A `.apexmountain` file is
a small reproducible recipe, not a prebuilt rendered scene or the binary bake.

### Validation commands

- `tests/density_spatial_suite.gd`: brute-force/grid equivalence, crash envelopes,
  material metadata, teleport retirement and recipe version selection.
- `tests/alpine_v13_suite.gd '--' --seed=849205174 --repeat`: v12 comparison,
  fresh repeat bake, warm-cache identity, seating, spacing, coverage and routes.
  Repeat separately for seeds 0, 42 and 2147483647 to keep residency bounded.
- The v13 route survey samples at 6 m across / 12 m downhill, with 1.8 m node
  and 1.5 m edge clearance. This permits technical gaps excluded by v12's
  3 m node / 2.5 m edge buffers; the solver still expands trunks by 0.35 m.
  When the coarse graph cannot resolve widely separated exits, a 3 m / 6 m
  refinement keeps the same physical clearance and endpoint requirements.
  Selected paths also undergo actual continuous trunk/mineral collision sweeps.
  Two exits must remain at least 500 m apart, with 144 m median reachable width.
  The original v12 survey and its thresholds remain available unchanged.
- Physics/runtime suites and relevant geology, tree grounding and graphics suites.
- `tests/alpine_v13_playtest.gd '--' --views --version=13`: all-face inspection
  and moving skiing samples. `--terrain-benchmark` measures dense sections
  without capture overhead. `scripts/benchmark_pc.ps1 -Version 13` runs a descent.

Native acceptance uses actual 3840×2160 output, High, 75% FSR2, 120 cap and SDFGI
off; target p95 <=11.1 ms and p99 <=16.7 ms. CPU/GPU timing, process RAM, VRAM,
loading time and achieved density are reported separately. Automated routes and
sampled images do not establish human skiing feel or temporal stability.

### Implementation validation

Automated: seeds 849205174, 0, 42 and 2147483647 each reach 200,000 trees and pass
independent deterministic reconstruction, cold/warm cache agreement, exact v12
support/material preservation, seating, trunk spacing, mineral/drop clearance,
broader obstacle coverage on every face and two branching paths per face. The
final suites include actual collision sweeps along the sampled paths. Some
faces require the finer survey grid described above; the original coarse-grid
failures remain in the guarded logs.

Regression suites pass: spatial/collision contracts 34 checks, tree derivatives
147, physics 56, runtime 126, geology collision 16, tree grounding 384, graphics
14 and recipe reconstruction 36. The headless graphics checks do not verify
appearance. Explicit v12 generator, geology and cache sources remain unchanged.

The default's 16,022 minerals comprise 4,076 small, 11,478 medium, 422 large,
22 huge boulders and 24 cliffs. Tree-occupied 48 m cells increase 4.19–6.35 times
and mineral-occupied cells 8.78–19.43 times across the six faces. Full per-face,
elevation, size and occupied-cell counts are in `artifacts/density_v13/report.md`;
source surveys and guarded logs remain alongside it.

Rendered: all six faces have skiing-height upper/middle/lower views and short
moving descents. The first 200k capture contains 36 stills and 18 three-second
moving samples, all without crashes; nearby native crash-body audits agree with
solid scenery. Reviewed images show broader woods, scattered trees, upper rock
features and open gaps. Nearby branches can obscure the third-person camera in
dense woods. Sampled frame sequences do not establish continuous motion quality
or human skiing enjoyment.

Automated descent limits: the old pilot crashes or stalls on v13. A test-only v13
pilot completes face 3 in 419.43 seconds; an independent replay of its ordinary
steer/tuck/brake/jump inputs reproduces the exact finishing position. The same
pilot crashes on faces 0/4/5 and stalls on 1/2. A v12 comparison completes face 2
with the current physics. These are unresolved automated skiing limits, despite
the collision-free branching survey; the generator does not use the test graph
to reserve racing lines, and production physics was not tuned to make the bot
pass.

Performance: a completed fresh v12 baseline predates rendering tuning; its dense
sections already exceeded the frame-time targets. Final 200k measurements run
with WoW and the user's existing background applications left running by request.
Per-process GPU utilization and whole-adapter memory are recorded separately.
They describe shared-load operation, not isolated 90–120 FPS acceptance. Earlier
native runs with source drift, allocation failures or smaller populations remain
identified in the evidence report.

Final all-face section run `density_v13_200k_culled` uses actual 3840×2160 output,
2880×1620 internal rendering, High, FSR2, 120 cap, SDFGI off and stable source
hashes. It follows the `density_v13_200k_shared` baseline and adds the hidden-LOD
optimization without removing trees. Across six four-second samples per band:

| Section | Average FPS range | Frame p95 ms | Frame p99 ms | Render CPU p95 ms | Render GPU p95 ms |
|---|---:|---:|---:|---:|---:|
| Upper slopes | 99.9–115.8 | 10.79–12.98 | 11.56–14.55 | 3.10–3.71 | 8.42–10.19 |
| Dense forests | 73.3–86.6 | 14.29–16.68 | 15.70–19.92 | 1.61–2.59 | 11.35–14.26 |

The dense-section p95 target is not met under this shared load. Forest averages
in the preceding run were 63.3–77.2 FPS; changing background load prevents
attributing that entire difference to the shader optimization. All twelve short
samples finish without a crash. The full 200,000-tree population remains enabled.

Loading and memory are separate costs: default cold generation was 171.28 s,
warm reconstruction 8.80 s, and the final native world build 78.33 s. The guarded
process tree peaked at 7.72 GiB private memory. Engine-reported video allocation
peaked at 5.26 GiB; Windows whole-adapter dedicated usage peaked at 10.46 GiB,
including WoW and other applications. These are different accounting scopes.
Final post-optimization capture adds 36 all-face stills; its timing samples
exclude image capture overhead.

The complete native face-3 descent (`density_v13_full_face3`) finishes without a
crash in 419.43 simulated seconds, peaking at 85.73 km/h. It uses the validated
ordinary-input recording and executes all 50,332 live 120 Hz simulation steps.
Source hashes remain stable. Actual 4K High performance with WoW running is
91.09 FPS average, frame p95/p99 16.19/18.79 ms; the forest portion averages
91.81 FPS with p95/p99 15.55/18.21 ms. Render CPU p95 is 3.79 ms and GPU p95
14.26 ms; simulation plus animation p95 is 1.453 ms per tick. Native world build
is 56.49 s, with 8.21 s warm mountain reconstruction reported separately. This
completed descent does not meet the requested frame-time acceptance gate.
Peak engine private memory is 7.57 GiB, with at least 2.67 GiB system RAM free;
whole-adapter dedicated usage peaks at 10.46 GiB. WoW is present throughout,
and no other Godot workload overlaps the complete-descent run.

Final release reruns of physics, runtime, graphics and tree derivative checks
all pass after the concurrent motion work and final shader edits. Matched v12
and v13 captures contain 36 views each at the same camera sites. Review panels
are in `artifacts/density_v13/matched_*.jpg`; the annotated 54-second compilation
`200k_all_faces_motion.mp4` uses the earlier 200k moving samples, before hidden-LOD
culling and with the source-drift caveat recorded above. It is inspection media,
not a frame-rate recording.

Human acceptance remains open: broader coverage and deterministic valid routes
do not prove the mountain is enjoyable, and one successful automated descent
does not establish successful skiing on all twelve sampled alternatives.
