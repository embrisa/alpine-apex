---
id: "AA-20260916-084508-reduce-presentation-terrain-probing"
title: "Cut presentation-side terrain probing and per-frame allocations in the effects path"
status: ready
priority: P2
depends_on: []
created: "2026-09-16T08:45:08Z"
updated: "2026-09-16T08:45:08Z"
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
  [the ten-ghost task](AA-20260912-132147-reduce-ten-ghost-presentation-cost.md);
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

Pending implementation. Record counts, scope timings, tests, rendered and
listening evidence, guide updates and commit/push references.
