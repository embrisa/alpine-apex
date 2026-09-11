# Golden cinematic sunlight at the existing noon

This page records the original v13 lighting pass. The current v14 appearance
retains its sun direction and sky fill; [snow readability](SNOW_READABILITY.md)
sets clear exposure to 1.15, reduces broad sheen/glow, and adds restrained cool
shading in real hollows. Current crystal and glow presets are also listed in
[DREAMLIKE_SNOW.md](DREAMLIKE_SNOW.md). The values below describe the original pass.

The original pass introduced warmer direct sunlight, luminous snow highlights, a larger controlled sun halo, HDR highlight glow and nearby shadowed volumetric light. The default remains **12:00 at the original 24-degree elevation / -58-degree orientation**. No afternoon offset or change to the 20-minute day cycle is applied.

It was introduced on the v13 mountain. Camera positions, authoritative 4 m terrain, collisions, tracks, race/replay identity and the independent 120 Hz solver were outside this presentation change. Existing assets and particle allocations were reused. No generation credits or purchases were used.

## Original implementation and settings

`presentation/alpine_atmosphere.gd` consumes the existing blended weather/daylight state from `alpine_world.gd`. It owns exposure, highlight rolloff, glow, and volumetric settings. `graphics_quality.gd` owns their quality switches. There is no extra timer or time-of-day state. Immediate quality changes reapply the current state; pause retains weather, clouds and wind, and restart retains the chosen settings and weather progression.

| Setting | Clear noon value |
|---|---|
| Direct sun | Energy 1.9; `#ffdfb1` |
| Ambient fill | Energy 0.38; `#b9d6f4`; existing 42% sky contribution |
| Sky top / horizon | `#2f6fa9` / `#c1d7e5` |
| Distant fog | Density 0.000065; `#b4c9da` |
| Filmic exposure / white | 1.3 / 2.8; smoothly returns toward 1 / 1 as daylight or clarity fades |
| Sun disc | HDR energy 14 at Clear noon; same angular disc size, broader multi-scale halo |
| Volumetric light | High only; 120 m length, density 0.0001, sun multiplier 16 |
| Volumetric sampling | 128 base resolution × 64 depth slices, filtering enabled |
| Scattering / history | Anisotropy 0.65; temporal reprojection amount 0.6; sky affect 0.65 |
| Volumetric GI / ambient injection | Both 0; moon injection 0 |
| Highlight glow | Balanced and High; intensity 0.18; additive, HDR threshold 1.4, full-screen bloom 0 |
| Low | Same warm light, sky and exposure; glow and volumetric shafts disabled |

Clear receives the strongest treatment. Cloudy has warm illuminated breaks with stronger direct illumination (0.85) and sharply reduced shafts. Snowfall and rain retain their overcast palette and contrast. Rays and daytime glow switch off at night; Weather FX Off retains the warm direct-light treatment and disables the added effects. Only the existing daylight controller sets the sun and moon directions.

The volume stays inside High's existing 160 m tree-shadow and 220 m terrain-shadow budgets. Minimal density limits extinction, while a directional-light multiplier makes the scattered light visible. Real directional shadows determine occlusion. The short history reduces trailing; no emissive beam meshes or screen-space fake rays are added. This follows [Godot's shadowed volumetric-lighting approach](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html).

Glow is limited to HDR highlights with bounded mip levels and no full-screen bloom. The bright sun disc is excluded from the radiance cubemap branch to avoid unstable environment-reflection sparkles. The HUD remains in the existing non-HDR 2D composition. See [Godot's glow controls](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html#glow).

Snow's existing world-anchored, sun/view-dependent crystals increase from strength 3.0 to 4.2; their derivative filtering, shadow attenuation and night suppression remain. Snow and rock roughness receive small reductions. Needle/branch-snow highlights stay broad, bark stays matte, and restrained needle transmission obeys geometry and cloud shadows. Slightly stronger existing needle wind and clear spindrift reinforce motion. Powder is more neutral in albedo, and formerly unlit precipitation/spindrift now shares real sun/cloud illumination. Particle counts are unchanged.

## Validation

Run `tests/golden_sunlight_suite.gd` and the relevant graphics/runtime checks.
Inspect current native clear/cloudy/precipitation and day/night views, including
canopy occlusion, shadowed shafts, highlight readability and quality transitions.
Compare moving scenes with capture-free timing as separate runs.

Old lighting comparison copies, galleries and benchmark reports were deleted.
They are not a current performance guarantee. Full v13 PC acceptance and human
comfort remain open; see [validation](VALIDATION.md). Later snow treatment is
documented in [DREAMLIKE_SNOW.md](DREAMLIKE_SNOW.md).
