# Softer, more luminous snow

The September 11 treatment preserves the scanned snow textures, world scale,
non-repeating tile placement and broad drift fields. It targets the user's
description of snow looking too "sharp", "crispy", "detailed" and "hard",
with a selected direction of "Soft and luminous". Visual acceptance remains
separate from shader correctness and frame timing.

## Material treatment

The shared terrain/powder fragment reduces the snow normal multiplier from
0.72 to 0.468 (35%), wind-ripple normals and their small AO cue by 25%, and
fine clump roughness amplitude from 0.10 to 0.05. Scanned color contribution
falls from 0.28 to 0.24 and scanned AO contribution from 0.20 to 0.12.
Rock normal/color/AO response and the terrain concavity shading are retained.
Snow caps receive the same 35% grain-normal and 50% micro-roughness reduction.

Balanced/High sun sheen rises from 0.084/0.132 to 0.1008/0.1584; highlight glow
rises from 0.252/0.35 to 0.2772/0.385. The existing quality binding applies
the sheen to terrain, High's replacement powder patch, caps and tracks.
Crystal intensity, density, placement and filtering retain their settings;
facet orientation still follows the resulting surface normal. Low retains
0.06 sheen, no crystal layers and no glow.

The broad reflection retains shadow/cloud attenuation and sun-horizon gating.
No emissive snow is added. Existing roughness floors, clear-day exposure 1.15,
HDR threshold 1.4, glow mip weights, bloom 0 and FSR sharpening 0.35 remain.
This changes no geometry, powder atlas, ski cuts/lips, particles, texture imports,
120 Hz simulation, terrain authority or replay/generator identity. No new user
setting, public interface or persistence schema is introduced.

## Reproduce the comparison

From the project root:

```powershell
python scripts/snapshot_snow_material.py 697a934bf44df6a1fc85ff83897be8eacff65164
./scripts/validate_soft_snow.ps1 -Stage checks
./scripts/validate_soft_snow.ps1 -Stage visual
./scripts/validate_soft_snow.ps1 -Stage timing
./scripts/validate_soft_snow.ps1 -Stage controls
python scripts/report_snow_readability.py --visual artifacts/soft_snow/visual --timing artifacts/soft_snow/timing --videos
python scripts/report_snow_readability.py --visual artifacts/soft_snow/controls --timing artifacts/soft_snow/timing
```

The report command needs Pillow and the existing local FFmpeg encoder. The
snapshot uses Git blobs to freeze the complete participating shader include
graph under ignored `artifacts/soft_snow/baseline/`, including the local powder
shader. Its manifest records original/frozen hashes and the exact baseline
revision. This is comparison evidence, not a game fallback or historical map.

The fixture uses the validated v15 Standard bake, seed 849205174. It swaps
complete material shader graphs in one world and applies each look's quality
values throughout motion. All runs are automated/unranked and do not save player
preferences. World, camera, weather and input states are matched; trajectory
hashes and source/engine identities are recorded. Still particles are frozen;
motion particles advance with fixed simulation time.

Output and retained motion frames are 3840x2160; motion is 30 fps review footage
with four 120 Hz solver ticks per frame. Main captures use High, Auto FSR 75%,
frame generation off and SDFGI off. Native 4K controls remove temporal upscaling.
Stills cover clear/cloudy/snowfall snow, sun angles, close powder, tracks at all
presets, forest night and Weather FX Off. Motion covers chase/first-person open
snow and forest chase. ABBA timing uses separate uncaptured open/forest runs
at a 120 rendered FPS cap, recording frame p95/p99, CPU/GPU and memory telemetry.
These short fixtures do not establish full-descent performance.

## Validation and remaining opportunities

The 14 PC-graphics, 50 golden-sunlight, 33 snow-response, 16 snow-readability
and 29 native graphics checks passed (142 total). The native material fixture
also passed: crystal/sheen highlights respond to cast shadows and have zero
changed pixels in the night isolation. It completed without a crash or record
eligibility. The first mountain capture attempt found a missing apron shader
in the comparison snapshot; the complete frozen graph and rerun passed.

The v15/model-28 comparison produced 23 matched still pairs and three four-second
4K motion pairs (open chase, open first person and forest chase), without crashes
and with identical before/after trajectory hashes. The forest fixture meets a
trunk midway through the clip, limiting its traversal coverage. Inspecting paired
stills and sampled motion frames shows less fine grain contrast, retained broad
folds and visible track lips/crystals. These observations are not user acceptance
or a guarantee of shimmer-free motion at every speed and angle.

The initial native-control pair matched before/after but used a different camera
direction from its FSR counterpart because the reset fixture retained a prior
ski-forward presentation value. `-Stage controls` uses an explicit downhill
camera, fixed across native and Auto FSR, in open snow and forest shade. Keep
this supplementary control evidence separate from the first capture's provenance.
All four supplementary A/B pairs passed, and camera position/basis, weather and
hour match across all four images per site (two looks, two rendering modes).
The exported generation dependency receipt was refreshed with the same runtime;
only the graphics-quality digest and resulting scenery signature changed.

Separate uncaptured ABBA timing used 3840x2160 output / 2880x1620 internal pixels,
FSR 4.1.1, frame generation off and a 120 rendered FPS cap on the RX 9070.
The table is the mean of two runs per look/site, not pooled percentiles:

| Fixture / look | Frame mean ms | p95 ms | p99 ms | GPU mean ms | Render CPU mean ms |
|---|---:|---:|---:|---:|---:|
| Open / before | 8.982 | 10.961 | 12.752 | 7.235 | 1.692 |
| Open / softer | 9.180 | 12.058 | 13.979 | 7.298 | 1.772 |
| Forest / before | 11.066 | 13.906 | 14.843 | 10.386 | 1.178 |
| Forest / softer | 11.242 | 14.260 | 15.375 | 10.537 | 1.180 |

The new look averaged 2.2%/1.6% longer frames in these short open/forest samples;
GPU mean increased 0.063/0.151 ms. Two repeats cannot establish a small causal
performance difference. The forest still misses the 11.1 ms p95 target and
full-descent performance remains unverified. All eight trajectories matched their
comparison counterparts. Peak guard totals were 5.77 GiB private memory,
1.97 GiB working set and 4.06 GiB per-process dedicated GPU allocation; these
are allocation counters, not physical VRAM residency. Godot's peak video-memory
counter was 3.45 GiB. Engine SHA-256 and current/frozen source hashes are in
the reports under `artifacts/soft_snow/`; guarded logs preserve attempt history.

The treatment introduces no extra texture samples, render passes or geometry.
Any future filtering or scattering work should start from matched native and
upscaled motion evidence; no additional rendering system is needed for this pass.
