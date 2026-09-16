---
id: "AA-20260916-084507-reduce-powder-patch-render-cost"
title: "Reduce the local powder patch's vertex, shadow and per-frame rebuild cost"
status: ready
priority: P1
depends_on: []
created: "2026-09-16T08:45:07Z"
updated: "2026-09-16T14:41:25Z"
source_thread: null
---

# Reduce the local powder patch's vertex, shadow and per-frame rebuild cost

## Outcome

Keep the local snow deformation look at High and Ultra while cutting the cost
of the 32 m powder patch, which currently rasterises about half a million
triangles with a heavy vertex shader in every geometry pass, casts its own
shadow, and rebuilds its GPU atlas every frame while the rider is grounded.

## Current state and evidence

- [The GPU task](AA-20260912-105302-reduce-dense-scene-gpu-cost.md) recorded
  that disabling powder saved about 1 ms GPU (rejected for quality loss) while
  the compute reconstruction itself is only 0.033 ms, so the cost is the
  patch's geometry passes, not the compute.
- Source inspected at Dev 43 / `a9c2acb` (2026-09-16):
  - [`powder_surface.gd:5-7`](../../scripts/presentation/powder_surface.gd)
    `RESOLUTION 1024`, `SUBDIVISIONS 512`; `_mesh()` (lines 137-158) builds
    about 263k vertices / 524k triangles for a 32 m patch (6 cm spacing).
    Line 71 sets `cast_shadow = ON`; line 298 rewrites the instance custom
    AABB on every presentation.
  - [`powder_surface.gdshader:30-50`](../../assets/graphics/powder_surface.gdshader)
    vertex evaluates `powder_height` five times (lines 34, 38, 39), each a
    `textureLod` plus two `powder_noise` calls (four `sin` each in
    `powder_surface.gdshaderinc:43-55`), `contact_rock` and `powder_support`
    (three to four `texelFetch`), plus `contact_cloud` (three
    `sample_cloud_light` calls, each three-octave noise) and four
    `contact_height` fetches: about 25 fetches and about 100 ALU per vertex,
    across pre-pass, opaque and up to four shadow splits.
  - `powder_surface.gd:258` skips the rebuild only when
    `not sim.grounded and not track_history.has_method("surface_materials")`.
    `GhostStack` defines `surface_materials`, so with a ghost stack bound the
    skip never triggers, and while skiing `grounded` is true anyway. Every
    frame therefore runs `take_gpu_updates`, `live_gpu_strokes().to_byte_array()`,
    a `_receiver_rids()` allocation, a bound Callable and three compute
    dispatches (`dispatches` in `budget()` will equal the render frame count).
    The clause dates from `259b50b` (2026-09-12). The `snow_tracks_powder` CPU
    scope is 179-288 µs mean per frame in the committed receipts.
- Snow presentation contracts live in
  [Rendering](../../docs/RENDERING.md#snow-presentation); the interface powder
  checks in `tests/interface_powder_native_checks.gd`, `tests/powder_upload_suite.gd`
  and `tests/powder_volume_suite.gd` cover upload validity and volume.

## Agreed decisions and scope

Own `scripts/presentation/powder_surface.gd`, `assets/graphics/powder_surface.gdshader`,
`powder_surface.gdshaderinc`, the powder compute shader and the powder-related
discard in `assets/graphics/alpine_surface_fragment.gdshaderinc:16-18`. Keep
the 32 m extent, the 1024 atlas, the ring/stroke budgets, the exact upload
validation, no readback and the current visible relief at riding distance and
in the first-person view. Grooves of about 12 mm must still resolve. Ghost
track history semantics belong to the ghost tasks; only the rebuild gating in
this file changes.

## Implementation approach

1. Fix the skip condition: rebuild when the history revision, live strokes or
   centre changed, independent of `grounded` and of the stack type; verify
   `budget().dispatch_frames` drops far below the frame count while gliding on
   unchanged tracks and that fresh strokes still appear the same frame.
2. Have the compute imprint pass also write height plus gradient (or a
   packed normal) so the vertex shader does one fetch instead of five height
   evaluations; move `contact_cloud` to per-patch or per-fragment low
   frequency where identical in stills.
3. Measure `SUBDIVISIONS` 256 (12.5 cm) against 512 in matched native stills
   at riding and first-person distances; keep 512 only if 256 visibly loses
   relief.
4. Set the patch `cast_shadow` off and guard the terrain's powder discard with
   `!IN_SHADOW_PASS` so the underlying terrain casts there; compare shadow
   stills. Keep the AABB static (it already spans plus or minus 120 m in
   height) so the instance is not dirtied every frame.

## Acceptance and verification

- [ ] `dispatch_frames` no longer tracks the render frame count on unchanged
  tracks; new strokes still present within one frame; upload validation and
  rejection paths unchanged.
- [ ] Matched native stills at 4K High of fresh carves, side-slip, first-person
  view and shadowed patch areas show no visible relief or shading loss for the
  chosen subdivision and vertex path.
- [ ] `tests/powder_upload_suite.gd`, `tests/powder_volume_suite.gd`,
  `tests/powder_support_cache_suite.gd`, `tests/interface_powder_native_checks.gd`,
  `tests/snow_response_suite.gd`, `tests/carving_raised_ski_tracks_gpu_suite.gd`
  and `tests/runtime_suite.gd` pass.
- [ ] One warmed 15-second powder-route candidate (the `powder` section of the
  v15 baseline or the dense route) with GPU ms, `snow_tracks_powder` scope and
  frame statistics versus the saved baselines.
- [ ] Update [Rendering](../../docs/RENDERING.md#snow-presentation) budgets,
  commit/push with a development note and Dev ID.

Human acceptance: the user's look at fresh powder relief in motion is a
follow-up, not a gate, when stills match.

## Open questions

None

## Completion record

Subdivision-only candidate retained after Windows review: 512 -> 256,
524,288 -> 131,072 triangles, same 32 m extent/maps/shader/shadows/track semantics.
Chase, low-angle, production first-person and moving recenter-frame comparisons
passed; 269 checks passed (support 24, response 33, runtime 192, uploads 13,
cosmetic GPU tracks 7). The full legacy volume/interface-mountain matrix was not
needed for this isolated constant; broader shader/gating work still requires
its affected checks. The full task acceptance list is not complete.

Three clean candidate observations saved 0.346-0.397 ms GPU. Initial 92.38 and
91.31 FPS samples had worse p99 versus saved 91.06; one same-process comparison
resolved the larger p99 difference: 90.74 -> 93.26 FPS, 11.021 -> 10.723 ms,
GPU 9.931 -> 9.585 ms, p95 13.398 -> 13.147, p99 15.025 -> 15.078. Maximum
frame time still grew 18.439 -> 23.316 ms; hitch improvement and sustained
90-120 FPS remain unproven. Reuse 92.28 FPS / 10.837 ms, the average of the two
cache-hit candidate samples.

Atlas dispatch gating, height/gradient packing, shadow and AABB proposals remain
unimplemented. This task remains ready for those separate hypotheses. Source
and mesh budgets are in Rendering; compact evidence is
`artifacts/powder_mesh_20260916/REPORT.md` and `reusable_baseline.json`.
