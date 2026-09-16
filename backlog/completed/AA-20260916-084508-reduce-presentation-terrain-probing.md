---
id: "AA-20260916-084508-reduce-presentation-terrain-probing"
title: "Cut presentation-side terrain probing and per-frame allocations in the effects path"
status: done
priority: P2
depends_on: []
created: "2026-09-16T08:45:08Z"
updated: "2026-09-16T19:10:06Z"
source_thread: null
---

# Cut presentation-side terrain probing and per-frame allocations in the effects path

## Outcome

Lower the `effects`, `camera` and `weather_world` render-frame CPU scopes by
removing Dictionary-returning terrain queries, redundant footprint probing and
per-frame allocations from presentation code, without changing any effect,
camera framing or audio behaviour.

## Current state and evidence

Recorded scopes: `effects` 770-1,073 µs mean per frame (p95 963-1,926 µs),
`camera` 120-134 µs, `weather_world` 138-199 µs, `audio_observers` 56-90 µs
per tick in the committed receipts. Source inspected at Dev 43 / `a9c2acb`
(2026-09-16):

- [`heightfield_surface.gd:75-98`](../../scripts/world/heightfield_surface.gd)
  `sample()` returns a `{height, normal}` Dictionary with a normalized Vector3
  per call. Presentation callers use it about 50-150 times per frame where
  only the height is needed: `chase_camera.gd:186-201, 276-308` (5-32 probes
  plus a `ray_geology` raycast per camera per frame, doubled when the preview
  camera is open), `snow_tracks.gd:150-156` (four per stamp),
  `speed_effects.gd:754`, `skier_animation.gd:339` (five per attempt),
  `weather_effects.gd:129`, `voice_environment.gd:91`. The allocation-free
  `sample_height`/`height_at` path already exists.
- [`snow_response.gd:147-206`](../../scripts/presentation/snow_response.gd)
  `resolve_track_contact` probes two nine-point footprints per ski on the
  unsupported/carving path (each point: `TerrainMaterial.at`, `surface.sample`,
  `snow_depth_at`, about 72 queries per ski) and allocates a rejection
  Dictionary and Array on every rejecting probe (every airborne frame). Called
  from `speed_effects.gd:750` per frame and again from ghost capture.
- [`equipment_audio_contacts.gd:31-106`](../../scripts/presentation/equipment_audio_contacts.gd)
  snapshots twelve proxy Dictionaries, builds `Array[AABB]`, tests 66 capsule
  pairs and calls `Geometry3D.get_closest_points_between_segments` (fresh
  `PackedVector3Array`) up to 25 times per surviving pair every frame;
  [`procedural_sfx.gd:196`](../../scripts/presentation/procedural_sfx.gd)
  builds a `presentation_mode` String per frame. Line 62 resets equipment
  contacts whenever `dt > .10`, so equipment audio silently drops below 10 FPS.
- [`weather_state.gd:34-36`](../../scripts/presentation/weather_state.gd)
  blends 16 fields through `set`/`get` reflection (48 calls per frame) from
  [`weather_controller.gd:126-215`](../../scripts/presentation/weather_controller.gd),
  which also formats `"%s → %s"` every frame during blends;
  `storm_effects.gd:89` hides six bolts every frame.
- [`snow_tracks.gd:126-242`](../../scripts/presentation/snow_tracks.gd)
  allocates corner arrays, nested literals, a `PackedFloat32Array` and a
  `values` Array per frame for live strokes.
- `skier_visual.gd:217` compares a float product to `1.0` exactly, so
  procedural limb rotations recompute on virtually every blend frame.
- Ghost-specific probing (`ghost_field.gd` track presentation) belongs to
  [the ten-ghost task](../tasks/AA-20260912-132147-reduce-ten-ghost-presentation-cost.md);
  uniform writes belong to
  [the shared uniform task](AA-20260916-084503-publish-shared-shader-uniforms-globally.md).

## Agreed decisions and scope

Own the listed presentation scripts. Keep camera framing, terrain clearance
behaviour, spray/track/powder placement, weather blending, storm effects and
equipment audio identical. Height-only substitutions must use the exact same
authority path (`sample_height`) so values are bit-identical. Footprint
probing may be reduced only by early rejection on the cheap reach/clearance
tests or by sharing results between callers in the same frame, never by
changing which contacts qualify. Fix the `dt > .10` reset by scaling the
sweep to the actual `dt` or clamping rather than dropping contacts.

## Implementation approach

1. Add temporary counters for `sample`, `sample_height`, `snow_depth_at` and
   `TerrainMaterial.at` per frame from presentation callers; record them.
2. Replace height-only `sample().height` uses with `sample_height`; add a
   `normal_at` helper only where a normal is actually consumed.
3. Reorder `resolve_track_contact` so the cheap clearance/reach test rejects
   before probing; reuse one rejection record; share the per-ski result within
   a frame between sprays/tracks and ghost capture where inputs are identical.
4. Keep persistent proxy arrays in equipment contacts, skip when equipment is
   hidden or the listener is distant, and cache `presentation_mode` on change.
5. Blend weather state with direct typed assignments; compute the blend label
   on phase change; gate storm bolt hiding on state change.
6. Preallocate live-stroke buffers in snow tracks; scale camera probe count
   with boom length and skip `ray_geology` when the previous frame had no hit
   and the boom moved less than a small threshold, only if framing stills are
   identical.

## Acceptance and verification

- [ ] Query and allocation counts fall; `effects`, `camera` and
  `weather_world` scopes fall measurably with `-ProfileFrameCosts`.
- [ ] `tests/snow_response_suite.gd`, `tests/camera_suite.gd`,
  `tests/camera_slope_suite.gd`, `tests/camera_profiles_suite.gd`,
  `tests/weather_suite.gd`, `tests/equipment_audio_suite.gd`,
  `tests/sfx_audio_suite.gd`, `tests/snow_contact_visual_suite.gd`,
  `tests/skier_voice_suite.gd` and `tests/runtime_suite.gd` pass.
- [ ] Rendered inspection: camera clearance over ridges and trees, sprays and
  tracks while carving, airborne, weather blends and storm; listening check
  of equipment clatter during a short descent.
- [ ] One warmed open-route candidate (CPU-bound route) with frame means and
  p95/p99 versus the saved baseline.
- [ ] Update the owning guide sections only where a contract changes;
  commit/push with a development note and Dev ID.

Human acceptance: camera feel and audio are follow-up listening/playtest items,
not gates, because behaviour is required to be unchanged.

## Open questions

None

## Completion record

### Delivery, 2026-09-16: implemented on `main` (Fable, macOS checkout)

Implemented manually; no scheduled claim. Owned paths: `chase_camera.gd`,
`speed_effects.gd`, `snow_tracks.gd`, `skier_animation.gd` (clearance
margin), `weather_effects.gd`, `voice_environment.gd`, `weather_state.gd`,
`weather_controller.gd`, `procedural_sfx.gd`, `prop_collision_surface.gd`.

What changed (effects, framing, audio and placement identical):

- Height-only terrain reads use the exact allocation-free `sample_height`
  when the surface offers it (camera boom, clearance probes and slope
  secants; spray tail origins; track stamp centre and four corners; the five
  animation clearance joints; weather drifts; voice terrain survey). Each
  caller caches the capability per surface object, so laboratory stubs with
  only `sample()` keep the original path. `PropCollisionSurface` forwards
  `sample_height`. `has_method("ray_geology")` and `has_method("bounds")`
  are resolved once per surface instead of per probe.
- Spray process uniforms (six per spray, six sprays) are written only when
  their value changes; idle sprays stop issuing 36 material writes per frame.
- Track stamps use four scalar corner heights instead of a typed Array and
  the rock-strip check uses the same three lerp points without an Array; the
  live GPU stroke buffer and history stroke writes reuse persistent buffers
  (consumers copy bytes immediately).
- `WeatherState.blend` assigns its sixteen fields with typed lerps instead
  of 48 reflective `set`/`get` calls; the blend label formats only when the
  preset pair changes; the equipment mode string rebuilds only when its four
  inputs change.
- Declined: the `dt > .10` equipment reset stays because
  `equipment_audio_suite` asserts "Long frame gaps re-prime without false
  hits" (removing it produced a strike from a 0.5 s gap); reusing one
  rejection record would alias entries the carving capture stores across
  frames; `resolve_track_contact` already returns before probing whenever a
  ski is in snow contact, so its footprint probes only run for an unsupported
  ski beside a carving one; equipment contacts measured 12 us per frame
  (`sfx_advance` scope), too small to justify a proxy-array refactor; the
  `skier_visual` exact `!= 1.0` compare is behaviour, not waste.

Measured on the Apple M4 MacBook (Metal, bilinear 0.75, Standard mountain
free ski, `scripts/mac_frame_probe.sh`, 20 s after warm-up; +/-1.5 ms frame
noise, scope means in us):

| Scope | Before | After |
| --- | --- | --- |
| `camera` | 73 (p95 99) | 68 (p95 93) |
| `effects` | 276 (p95 415) | 254 (p95 400) |
| `snow_tracks_powder` | 171 (p95 283) | 148 (p95 267) |
| `weather_world` | 180 (p95 273) | 165 (p95 254) |
| `audio_observers` | 23 (p95 51) | 22 (p95 48) |

Baseline is the instrumented run before the change, candidate the mean of three runs. Untouched scopes
(`pose`, `simulation`) drifted 3-7 percent lower across the same runs, so the
attributable saving is roughly half of each difference: tens of microseconds
per frame in total, not a frame-rate change on this GPU-bound machine. The
new `powder_surface` sub-scope (about 85 us) belongs to task `084507`.

Automated (macOS, Godot 4.7.2): snow_response_suite 33/33, camera_suite 766/766, camera_slope_suite 1136/1136, camera_profiles_suite 1975/1975, weather_suite 44/44, equipment_audio_suite 44/44 (after keeping the long-frame reset), snow_contact_visual_suite 129/129, skier_voice_suite 209/209, runtime_suite 192/192, native powder_upload_suite 13/13; sfx_audio_suite 30/31 with the one failure environmental (the native audio library is Windows-only, so 'Native availability matches explicit fallback switch' cannot pass on macOS). tests/interface_performance_suite.gd-style Windows scope receipts were not re-measured.
