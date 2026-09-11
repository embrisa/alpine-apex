# Dreamlike snow crystals and sunlight

The shared snow presentation uses dense, bright crystal reflections and a warm
sun sheen. The subsequent [snow readability pass](SNOW_READABILITY.md) reduces
broad sheen, glow and clear-day exposure, and adds cool shading to actual terrain
hollows. The [soft snow pass](SOFT_SNOW.md) subsequently softens fine relief and
raises sheen by 20% and highlight glow by 10% from the readability defaults.
The table below reflects the current defaults. Crystal density,
individual sparkle, sun direction and physical terrain remain unchanged.
The original evidence later on this page describes the v13 dreamlike treatment;
the readability page records current v14 validation separately.

## Material treatment

Two world-locked facet fields use independent grain placement and orientation.
Fine grains retain a 24-cells/metre field and fade over 10–32 m. Larger grains use
8 cells/metre and fade over 20–60 m. Pixel-footprint filtering fades both before
undersampling; these ranges are maximum visibility envelopes, not a guarantee
that every grain remains visible at their far edge. Density changes facet
occupancy separately from highlight strength. Neither layer has an animation
clock or emission term. Low skips both facet samples.

A broad half-vector lobe supplies sun sheen after grains become unresolved. It
uses snow coverage, wind packing and local compaction on terrain/powder, and
groove/slip response on tracks. The new sheen and larger grains exclude exposed
rock and mineral ice. Snow caps share the response. Off-map material blending and
the plain geometry diagnostic suppress the new terms along with existing detail.
Only participating snow shaders compile this extension to shared lighting.

Both reflection layers retain real directional-light shadow attenuation and
cloud transmission. They are suppressed when the sun is below the horizon;
neither moonlight nor point lights receives the added lobe. Weather FX Off keeps
sunlit material reflection, matching its previous behaviour, and disables glow
and volumetric effects. Snowfall and rain retain their overcast palette.

| Setting | Low | Balanced | High |
|---|---:|---:|---:|
| Crystal strength | 0 | 6.0 | 9.0 |
| Crystal density | 0 | 1.35 | 1.75 |
| Snow sheen strength | 0.06 | 0.1008 | 0.1584 |
| Clear-noon highlight glow intensity | 0 | 0.2772 | 0.385 |

The existing seven glow mip weights are now `[0, .25, .65, .45, .12, 0, 0]`.
The HDR threshold remains 1.4, full-screen bloom remains zero, and the HUD stays
outside HDR 2D processing. Existing daylight/cloud gating scales glow intensity.
The graphics resource binds strength, density and sheen together on creation and
live quality changes; tracks retain their previous 0.35 sparkle multiplier. There
is no new user setting or preference migration.

## Reproduction and acceptance

`scripts/snow_dreamlike_snapshot.py` preserves a private baseline containing the
working source and imported assets, then builds a paired project with exactly
ten runtime file differences. Immutable binaries are shared only between those
private snapshots. Concurrent working-tree changes are not copied into the pair.

Run the existing graphics, snow-response and golden-sunlight suites for automated
contracts, and `tests/snow_dreamlike_material_playtest.gd` for native rendered
crystal/sheen/glow isolation, actual cast-shadow attenuation, track/powder views
and night suppression. The exact-image diagnostic uses native AA and freezes
all particle families; production FSR2 is exercised separately.

`tests/snow_dreamlike_playtest.gd` extends the current v13 harness. Use `--views`
with seed 849205174, actual 3840×2160 output, High, 75% FSR2 and SDFGI off. It
captures matched summit/slope/forest views, quality levels, reflection distances,
a native-resolution control and chase/first-person motion. Motion advances the
solver at 120 Hz and presentation/particles at 60 Hz; 30 FPS review videos and
adjacent native frames are saved without treating capture time as a benchmark.

`scripts/benchmark_snow_dreamlike.ps1 -ProjectRoot <snapshot> -Label <label>
-Weather clear|snowfall` runs twelve four-second real-input skiing samples across
open snow and forest on all six faces, with 120 warmup frames per sample. It
records actual pixels, frame percentiles, renderer CPU/GPU time, solver time,
video memory and process/system memory. It is a bounded traversal benchmark,
not a full-descent frame-rate guarantee. Existing applications remain untouched
and other Godot/WoW process presence is recorded. All runs remain unranked.

`scripts/report_snow_dreamlike.py` builds the paired image/video gallery and
checks exact camera/weather/terrain metadata and simulation outcomes. Its
whole-frame SDR clipping statistic includes sky and sun; it is neither a snow
segmentation nor an HDR measurement.

## Acceptance

Old comparison projects, reports and captures have been deleted. Generate fresh
outputs when changing the material. Inspect sparkle stability, light/shadow
readability and actual moving snow on the current v13 mountain. Headless material
checks and frozen stills cannot establish continuous motion or player acceptance.
Use [current validation gates](VALIDATION.md) for full-mountain performance.
