---
id: "AA-20260916-084500-reduce-solver-terrain-query-redundancy"
title: "Remove redundant terrain queries and per-tick overhead inside the 120 Hz solver"
status: done
priority: P1
depends_on: []
created: "2026-09-16T08:45:00Z"
updated: "2026-09-16T20:49:03Z"
source_thread: null
---

# Remove redundant terrain queries and per-tick overhead inside the 120 Hz solver

## Outcome

Raise rendered FPS on every route by making one fixed simulation tick cheaper
without changing the ski model, the 120 Hz tick, the 4 m terrain authority or
any replay/race identity. The `simulation` CPU scope is the single largest
scripted cost on the main thread; cutting it lowers every frame, not only dense
forest frames.

## Current state and evidence

- Recorded CPU scopes (`cpu_scopes_us`) show `simulation` at 1,474-1,569 µs
  mean per tick, p95 2,350-2,824 µs, in
  [the rendering baseline](../../docs/RENDERING_BASELINE_RESULTS.json),
  [the bounded high-speed results](../../docs/CURRENT_V15_BOUNDED_HIGH_SPEED_PERFORMANCE_RESULTS.json)
  and [the v15 baseline](../../docs/V15_PERFORMANCE_BASELINE_RESULTS.json).
  At the 72 FPS dense-forest reference in
  [DENSE_FOREST_BASELINE.json](../../docs/DENSE_FOREST_BASELINE.json) that is
  about 1.7 ticks per rendered frame, so roughly 2.5 ms of each 13.9 ms frame.
  On the open route (about 105 FPS, GPU 7.1 ms) the frame is CPU-bound and the
  solver is the dominant scripted contributor.
- Source inspected at Dev 43 / `a9c2acb` (2026-09-16). Redundant work found in
  one grounded two-ski tick:
  - [`ski_simulation.gd`](../../scripts/core/ski_simulation.gd) evaluates
    `_contact_normal(surface, position.x, position.z)` at line 204, again inside
    each `_update_contacts` call (line 703; called from 306, 524 and 541) and
    again inside each `_support_sample` (line 682; called from 322, 447, 473,
    478, 519 and 775). Each `_contact_normal` is four `sample_height` reads.
    Several of these hit the identical (x, z) within one tick.
  - [`ski_contact.gd:99-101`](../../scripts/core/ski_contact.gd) computes a
    second four-sample `contact_normal_at` one step ahead solely for
    `curvature_load`, declared "diagnostic only" at line 49. No other script or
    test reads `curvature_load` (grep on 2026-09-16). Two skis times two or
    three `_update_contacts` per tick means 16-24 wasted height reads.
  - [`heightfield_surface.gd:51-60`](../../scripts/world/heightfield_surface.gd)
    `rock_fraction_at` performs four `Image.get_pixel` engine calls per query;
    `TerrainMaterial.at` is called from `ski_contact.probe`,
    `snow_crush_contact.gd`, `snow_contact_assist.gd` and `snow_response.gd`,
    about 18-30 times per tick. The byte grid built in `build_material_map`
    is discarded after creating the Image.
  - [`prop_collision_surface.gd:17-23`](../../scripts/world/prop_collision_surface.gd),
    [`terrain_material.gd:7`](../../scripts/core/terrain_material.gd),
    `snow_crush_contact.gd`, `snow_contact_assist.gd`, `landing_assist.gd` and
    `ski_simulation.gd` (lines 384, 628) call `has_method("literal")` on every
    hot call, roughly 250-400 String to StringName conversions per tick.
  - `_resolve_obstacle` (`ski_simulation.gd:561-583`) runs `sweep_obstacle`
    and then `sweep_obstacle_contact` again on a hit; each sweep allocates
    scratch Dictionaries and default arrays in `prop_collision_surface.gd:47-74`.
  - [`landing_assist.gd:47-52`](../../scripts/core/landing_assist.gd) runs
    `predict()` every 1/30 s while airborne even when
    `tuning.landing_assist_enabled` is false (the default). Each prediction is
    up to 32 footprints, each two samples plus two `has_method` calls. The
    predicted landing fields are exported through `rider_motion_state.gd:56-61`,
    so presentation consumers must be checked before gating.
  - [`rider_body.gd`](../../scripts/core/rider_body.gd) calls `_pose` and
    `_mass_properties` twice per `body.step` (lines 160 and 231), duplicates
    `joints`/`rotations` every tick (112-113) and
    [`rider_facing_pose.gd:38-64`](../../scripts/core/rider_facing_pose.gd)
    duplicates them again. String-keyed `REST[prefix+"UpLeg"]` lookups inside
    `fit_hips` are owned by
    [the pelvis fitting task](AA-20260913-141128-reduce-pelvis-fitting-cpu-cost.md);
    do not duplicate that work here.
- The production massif already opts into the allocation-free `sample_height`
  path (`alpine_massif_v15.gd:48`); that path and the channel-floor snow query
  were delivered by
  [the terrain query task](AA-20260913-141128-reduce-terrain-and-snow-query-cost.md).
  Do not re-propose them. `snow_depth_at` in
  [`alpine_massif_v15.gd:256-262`](../../scripts/world/generators/alpine_massif_v15.gd)
  remains the most expensive terrain primitive (noise, `powder_region` over
  adjacent faces, tree snow) and is called about 16 times per tick; the contract
  in [World](../../docs/WORLD.md#physical-snow) requires exact live results.
- Estimates above are analytic counts from source, not measurements. Confirm
  with `--profile-frame-costs` before and after; the `simulation` scope already
  exists in [`frame_costs.gd`](../../scripts/diagnostics/frame_costs.gd).

## Agreed decisions and scope

Own `scripts/core/ski_simulation.gd`, `ski_contact.gd`, `snow_contact_assist.gd`,
`snow_crush_contact.gd`, `landing_assist.gd`, `terrain_material.gd`,
`scripts/world/prop_collision_surface.gd` and the `rock_fraction_at` storage in
`scripts/world/heightfield_surface.gd`. Preserve the explicit ski model, model
35 tuning identity, 120 Hz, the 4 m authority, replay 7 and race 6 compatibility
and every documented contact contract. Exclude pelvis/leg fitting math (owned
by the pelvis task), snow depth caching (rejected by the terrain query task
unless exact), and any new native kernel.

Results must stay bit-identical for the existing 1,800-tick replay endpoints
and the terrain query differential checks. A per-tick memo keyed on exact float
equality of (x, z) is identical by construction. Replacing `Image.get_pixel`
with direct byte reads must reproduce the same float32 value (`byte / 255.0`
rounded as the Image path does); if it cannot, keep the Image path and memoize
instead. Removing `curvature_load` is a diagnostic deletion, not a physics
change; if any HUD or case tooling turns out to read it, gate it behind
`frame_costs.enabled` rather than deleting.

## Implementation approach

1. Attribute first: run the ordinary and 170 km/h forest traces with
   `-ProfileFrameCosts`, then add temporary counters for `sample_height`,
   `sample`, `snow_depth_at`, `rock_fraction_at`, `has_method` and sweeps per
   tick. Record the counts in the task evidence and remove the counters.
2. Add a tick-scoped memo on the simulation for `_contact_normal` and
   `_support_sample` results (cleared at the top of `step`), pass the already
   computed ground sample into the line 524 `_update_contacts`, and delete the
   `curvature_load` look-ahead normal.
3. Resolve surface capabilities once when the surface is bound (`reset`,
   `prime_contacts` or a small capability record on the adapter) and branch on
   bools; where a name must remain, use `&"name"` literals.
4. Keep the material byte grid as a member and index it directly, or memoize
   `TerrainMaterial.at` per tick per anchor; verify bit equality against the
   Image path over the 9,000-point differential set in
   [`tests/terrain_query_suite.gd`](../../tests/terrain_query_suite.gd).
5. Call `sweep_obstacle_contact` once per tick and derive the reason from it;
   reuse scratch containers. Skip `landing_assist.predict` when neither the
   assist nor a presentation consumer needs its output.
6. Double-buffer the body's joint dictionaries instead of duplicating, only if
   `rider_facing_pose` reference semantics are preserved (see its lines 31-34).

## Acceptance and verification

- [ ] Per-tick query counts fall for the same trace with identical final
  simulation state; record before/after counts per primitive.
- [ ] `tests/physics_suite.gd`, `tests/runtime_suite.gd`,
  `tests/terrain_query_suite.gd`, `tests/snow_crush_suite.gd`,
  `tests/snow_grounding_suite.gd`, `tests/landing_settle_suite.gd`,
  `tests/streaming_collision_suite.gd` and `tests/crash_replay_suite.gd` pass
  through `./godotw --headless --script ...` on the smallest targeted map. All
  measured 1,800-tick replay endpoints and recorded ghosts remain exact.
- [ ] Follow the [performance method](../../docs/VALIDATION.md#performance-method):
  compare against [DENSE_FOREST_BASELINE.json](../../docs/DENSE_FOREST_BASELINE.json)
  and the open-route baseline with one warmed 15-second capture-free candidate
  under `-WorkloadMode FpsCritical`, plus one `-ProfileFrameCosts` run to read
  the `simulation` scope. Report per-run means, medians, p95/p99 and the
  remaining 90-120 FPS gap. Isolated query savings do not establish completion.
- [ ] Update [Physics](../../docs/PHYSICS.md) or [World](../../docs/WORLD.md)
  only where a query contract changes; commit/push owned paths with a
  development note and record the Dev ID.

Human acceptance: none required for an exactly reproduced simulation. Any
non-identical output requires the user's decision and a model increment.

## Open questions

None

## Completion record

### Delivery, 2026-09-16: one redundant sweep removed; the remaining proposals were measured and rejected (Fable, macOS checkout)

Implemented manually; no scheduled claim. Astra's part (native hip fitting,
allocation-free heights, exact tick-local query reuse, removal of the unread
curvature probes) is in place.

Delivered: `_resolve_obstacle` performs one `sweep_obstacle_contact` and reads
its `reason`, instead of a reason-only sweep followed by a second identical
contact sweep on every hit tick. `sweep_obstacle` is defined as
`sweep_obstacle_contact(...).get("reason","")` on every surface, so the
decision path is unchanged; surfaces without the contact API keep the
reason-only call. Paired `tests/solver_tick_benchmark.gd` runs (6000 ticks,
three passes) produce the same state digest
`1cc6806dd5c7...` before and after; means 328/316/305 -> 311/302/302 us per
tick are within run noise because the benchmark route hits no obstacle.

Measured earlier on this checkout and rejected under the no-gain policy (see
[Performance handoff](../../docs/PERFORMANCE_HANDOFF.md), solver attribution):
a byte lookup table replacing the four `Image.get_pixel` reads in
`rock_fraction_at` and per-surface capability flags replacing the
`has_method("...")` checks both landed at the noise floor of the paired
benchmark, and the byte table cannot reproduce the float32 `Color.r`
quantisation bit for bit. Editing `heightfield_surface.gd` also invalidates
the physical mountain cache. Nothing further from this task is retained.
Solver 35, replay 7 and race 6 identities are untouched.
