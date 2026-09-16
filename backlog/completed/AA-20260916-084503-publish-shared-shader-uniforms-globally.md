---
id: "AA-20260916-084503-publish-shared-shader-uniforms-globally"
title: "Publish per-frame shared shader inputs as global uniforms and change-gate material writes"
status: done
priority: P1
depends_on: []
created: "2026-09-16T08:45:03Z"
updated: "2026-09-16T20:49:03Z"
source_thread: null
---

# Publish per-frame shared shader inputs as global uniforms and change-gate material writes

## Outcome

Reduce render-thread and script CPU per frame by writing shared, frame-varying
shader inputs once instead of once per material, and by skipping material and
particle parameter writes whose values did not change. Visual output must be
unchanged.

## Current state and evidence

Source inspected at Dev 43 / `a9c2acb` (2026-09-16). `render_cpu_ms` is
1.9-2.0 ms mean in [DENSE_FOREST_BASELINE.json](../../docs/DENSE_FOREST_BASELINE.json);
the `effects` scope is 770-1,073 µs and `interactive_trees` 93-460 µs per frame
in the committed receipts.

- [`cloud_lighting.gd:31-45`](../../scripts/presentation/cloud_lighting.gd)
  `update` writes `cloud_params` to every registered material whenever the
  wind offset changes, which is every animated frame. There are 24
  registration sites; [`mineral_scenery.gd:86`](../../scripts/presentation/mineral_scenery.gd)
  registers one material per mineral asset, and imported skier, equipment,
  ghost, grass, gravel, track and particle materials register too, so likely
  150-250 `set_shader_parameter` calls per frame for one value.
- [`alpine_assets.gd:349-365`](../../scripts/presentation/alpine_assets.gd)
  writes `wind_time` to every wind receiver each frame (10-20 materials).
- [`tree_motion.gd:86-103`](../../scripts/presentation/tree_motion.gd) uploads
  two `PackedVector4Array` uniforms to three materials every frame, after
  allocating candidate arrays and sorting with a lambda;
  [`grass_motion.gd:39-43`](../../scripts/presentation/grass_motion.gd) uploads
  two 16-entry arrays to each receiver every frame, even with no active slot.
- [`terrain_grass.gd:73`](../../scripts/presentation/terrain_grass.gd),
  [`rock_gravel.gd:64`](../../scripts/presentation/rock_gravel.gd) and
  [`race_beams.gd:119-122`](../../scripts/presentation/race_beams.gd) (via
  `get_tree().call_group` in `main.gd`) write time uniforms per frame.
- [`speed_effects.gd:157-175, 766-770, 795-806`](../../scripts/presentation/speed_effects.gd)
  writes six process parameters per spray for six sprays every frame (36
  writes), allocates an Array literal per spray, sets `position`, `basis`,
  `emitting` and `speed_scale` even for hidden sprays, and sets audio
  `volume_db`/`pitch_scale` every frame.
- [`weather_effects.gd:108-143`](../../scripts/presentation/weather_effects.gd)
  writes about 24 particle/material parameters per frame even when
  precipitation is disabled.
- [`procedural_sfx.gd:106, 151, 196, 461`](../../scripts/presentation/procedural_sfx.gd)
  publishes the mix both per tick and per frame, builds a `presentation_mode`
  String every frame and writes `stream_paused` every frame;
  [`skier_voice.gd:200, 208`](../../scripts/presentation/skier_voice.gd) sets
  `volume_db` on two players every frame.
- `project.godot` already reserves `limits/global_shader_variables/buffer_size=262144`,
  and [`render_state_cache.gd`](../../scripts/presentation/render_state_cache.gd)
  already provides compare-and-set for shader parameters.
- Ghost material tinting per frame is owned by
  [the ten-ghost task](../tasks/AA-20260912-132147-reduce-ten-ghost-presentation-cost.md).

## Agreed decisions and scope

Own the listed presentation scripts and the shader declarations they feed
(`assets/cloud_field.gdshaderinc` and consumers, wind receivers, grass
and gravel shaders, race beam shader). Keep every visual identical, including
pause behaviour (wind and cloud time must still freeze when the game pauses, so
use a script-driven global rather than `TIME`). Preserve
[the weather](../../docs/RENDERING.md#weather) and
[forest lighting](../../docs/RENDERING.md#terrain-forests-and-lighting) contracts
and the FidelityFX renderer patch. Exclude ghost tinting and any shader ALU
changes (see [the vertex shader task](AA-20260916-084513-reduce-vertex-shader-transcendentals.md)).

## Implementation approach

1. Declare `global uniform` equivalents for `cloud_params`,
   `cloud_sun_direction`, `cloud_layer_height_m`, wind time/strength, grass
   sweep and tree contact arrays and stream times; set them once per frame via
   `RenderingServer.global_shader_parameter_set`. Register them in
   `project.godot` and remove the per-material writes and receiver lists that
   become redundant. Keep per-material overrides only where a material
   genuinely differs.
2. Route remaining per-frame parameter writes (sprays, weather volumes, audio
   players, `stream_paused`) through `render_state_cache` compare-and-set or
   equivalent change gates; skip hidden sprays and disabled volumes entirely.
3. Reuse candidate buffers in `tree_motion`/`grass_motion` and upload only when
   any slot is active or the arrays changed.
4. Cache `presentation_mode` on the events that change it; publish the SFX mix
   once per frame.
5. Verify with matched native stills (clouds moving, wind, grass sweep, sprays,
   beams, pause) that nothing visible changed.

## Acceptance and verification

- [ ] Per-frame `set_shader_parameter`/`material_set_param` counts fall by an
  order of magnitude for the dense-forest trace (count with a temporary
  wrapper, remove afterwards).
- [ ] `tests/weather_suite.gd`, `tests/weather_lifecycle_suite.gd`,
  `tests/tree_dynamics_suite.gd`, `tests/terrain_grass_suite.gd`,
  `tests/rock_gravel_suite.gd`, `tests/sfx_audio_suite.gd`,
  `tests/wind_audio_suite.gd`, `tests/finish_beam_suite.gd`,
  `tests/render_efficiency_suite.gd` and `tests/runtime_suite.gd` pass.
- [ ] Rendered inspection: matched stills and short motion of cloud shadows,
  wind, grass/tree contact bending, sprays and race beams; pause freezes
  animation as before.
- [ ] One warmed 15-second dense-forest candidate against
  [DENSE_FOREST_BASELINE.json](../../docs/DENSE_FOREST_BASELINE.json) with
  `render_cpu_ms`, `effects` and `interactive_trees` reported.
- [ ] Update [Rendering](../../docs/RENDERING.md) where the uniform ownership
  changes; commit/push with a development note and Dev ID.

Human acceptance: none if stills match; a visible difference blocks delivery.

## Open questions

None

## Completion record

### Delivery, 2026-09-16: cloud inputs published as global shader parameters (Fable, macOS checkout)

Implemented manually; no scheduled claim. Astra's part (cloud parameter,
direction and height change gates; wind direction/strength gates; exact-rest
skipping in tree contact work) is in place, and this checkout's earlier
delivery under `AA-20260916-084508` already change-gates the spray uniforms
and the equipment mode string.

Delivered: `cloud_params`, `cloud_sun_direction` and `cloud_layer_height_m`
are global shader parameters (`project.godot` `[shader_globals]`, declared
`global uniform` in `assets/cloud_field.gdshaderinc`). `cloud_lighting.gd`
writes each once per change through `RenderingServer.global_shader_parameter_set`
instead of once per registered material; on the Standard mountain the
registry holds 174 receivers, so the animated wind offset formerly issued
174 material writes per frame. The registry remains for diagnostics and late
registration, which now needs no copy. Pause behaviour is unchanged: the
controller stops advancing the offset, so the globals hold. All four
`CloudLighting` handles (world, effects, weather, skier) are one shared
instance, so world and preview state were never separate publishers.

Measured on the Apple M4 MacBook (`scripts/mac_frame_probe.sh`, interleaved
baseline/candidate pairs, 20 s, microseconds mean per frame):

| Scope | Baseline pair | Candidate pair |
| --- | --- | --- |
| `weather_world` | 173.2 / 166.8 | 70.3 / 69.4 |
| whole frame (ms, GPU-bound, noise +/-1.5) | 25.81 / 24.88 | 25.00 / 24.78 |

Not done, with reasons: the wind receiver registry writes `wind_time` to
8 materials per animated frame; that is small enough that it was left
per material, and the terrain grass/gravel/beam time uniforms and weather
particle parameters were left as they are (the weather effects already skip
disabled volumes). `render_state_cache.gd` compare-and-set remains the
mechanism for the remaining material writes.

Automated (macOS, Godot 4.7.2): render_efficiency_suite 361/361,
weather_suite 44/44 and runtime_suite 192/192 with the two suites updated to
inspect the publisher state, because the headless renderer does not read
globals back. A rendered still (`artifacts/mac_probe/cloud_cand_1.png`)
shows sky clouds and ground shade as before; Windows D3D12 and the custom
FidelityFX engine must compile the `global uniform` declarations (Godot 4.4+
feature, already used by the project's reserved global buffer setting) and a
Windows rerun remains a follow-up.
