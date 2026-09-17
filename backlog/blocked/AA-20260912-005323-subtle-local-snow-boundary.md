---
id: "AA-20260912-005323-subtle-local-snow-boundary"
title: "Make the moving local snow-detail boundary less noticeable"
status: blocked
priority: P2
depends_on: []
created: "2026-09-12T00:53:23Z"
updated: "2026-09-17T00:13:30Z"
source_thread: null
---

# Make the moving local snow-detail boundary less noticeable

## Archive update - 17 September 2026

The integration-closure follow-up was archived at the user's request.
This parent record keeps its blocked status and evidence; the retired
follow-up no longer owns further work. Resuming this record requires an
explicit scope and retry decision.

## Outcome

Preserve the intentional detailed snow around the player, while making its
boundary and updates subtle during riding. The user sees a square whose edge
visibly updates as they progress and finds it strange and off-putting. Nearby
snow should retain its relief and ski response without a conspicuous advancing
square, popping strip or moving shading seam.

## Current state and evidence

Source inspected on 2026-09-12; the reported artifact has not been reproduced
in a native capture during authoring.

- [PowderSurface](../../scripts/presentation/powder_surface.gd) builds a 32 m
  square with 512 subdivisions per axis. `update_surface` snaps both center
  coordinates to 4 m, moves the replacement mesh and updates shared material
  centers, then schedules GPU reconstruction from bounded track history.
- [Powder helpers](../../assets/graphics/powder_surface.gdshaderinc),
  `powder_edge`, already fade relief between square radii 11 and 15 m using
  max-axis distance. Fresh relief is world-space noise; its depth comes from
  the rider's sampled loose snow. A fade exists, so simply proposing to add
  one does not address the temporal or material handoff.
- [Shared terrain fragment](../../assets/graphics/alpine_surface_fragment.gdshaderinc)
  discards base terrain throughout the full 32 m replacement rectangle.
  [Replacement vertices](../../assets/graphics/powder_surface.gdshader) sample
  exact 4 m contact triangles but reconstruct normals differently from
  [base terrain](../../assets/graphics/alpine_surface.gdshader). Normal/lighting
  mismatch and the snapped relief envelope are candidates to isolate, not
  confirmed causes. Check render-thread texture/center synchronization too.
- [GraphicsPresets](../../scripts/presentation/graphics_presets.gd) enables
  local deformation at presets 7-10 and exposes an independent override.
  [Rendering](../../docs/RENDERING.md#snow-presentation) owns the presentation
  and upload contracts; [validation](../../docs/VALIDATION.md) owns evidence.
- No duplicate boundary task was found in active/archive tasks or ideas.
  [Raised-ski tracks](../abandoned/AA-20260911-225724-carving-raised-ski-tracks.md) and
  [ghost tracks](AA-20260911-220556-animated-ghost-snow-tracks.md) may touch shared
  snow code; coordinate edits without changing their contact/emission scope.
  [Distant snow](AA-20260911-230603-scenery-snow-material.md) concerns scenery,
  not this local patch. None is a prerequisite.

## Agreed decisions and scope

- Keep the detailed local snow, live impressions and retained trails. Smooth
  the handoff into surrounding terrain and its movement; do not solve this
  by disabling deformation, flattening nearby snow or hiding it with blur/fog.
- Presentation only: preserve the Node-independent 120 Hz solver, shared 4 m
  terrain, support/contact rules, replay and race identity. The rendering center
  need not inherit physical-grid snapping if exact contact triangles remain valid.
- Keep the bounded local-patch architecture and existing graphics controls.
  Prefer a local shader/transition correction within current mesh/atlas budgets;
  avoid expanding detail across the mountain or adding a new user setting.
- No general snow-material, camera, animation, weather or engine redesign.
  Follow the [incremental engine strategy](../../docs/ARCHITECTURE.md#engine-strategy).

## Implementation approach

1. Freeze a current-source baseline and reproduce with local deformation on/off
   while riding through several X, Z and diagonal recenter thresholds. Inspect
   full chronological frames at the forward edge and corners; isolate geometric,
   normal/material, shadow and atlas-handoff contributions.
2. Make base and replacement geometry/shading converge at the boundary. Decouple
   a smoothly moving visual influence from snapped storage as appropriate, or
   use another bounded transition proven in motion. Keep the visible envelope
   inside valid mesh/atlas coverage, including corners and fast diagonal travel.
   Leave exact fade widths and interpolation choices to measured implementation.
3. Keep fresh detail and existing grooves fixed in world space as the patch
   moves. Preserve full nearby ski detail and shared mapping between terrain,
   replacement mesh and ribbons. Do not interpolate an atlas origin independently
   of its contents. Publish coherent texture/mask/mesh state; no one-frame holes,
   doubled surfaces, covered grooves, z-fighting or trailing old patch.
4. Handle stops, threshold reversals, fast riding, air/landing, reset/teleport,
   terrain edges and runtime deformation toggles. Reset any transition state
   explicitly on discontinuities. Preserve rock exclusions and bounded GPU
   uploads; no production readback or mountain-wide per-frame CPU work.
5. Add a focused moving-boundary fixture and update the owning snow rendering
   guide with the adopted handoff contract. Keep evidence under a task-specific
   `artifacts/local_snow_boundary/` directory.

## Acceptance and verification

- [x] Matched before/after native clips show a substantially less noticeable
  advancing boundary during ordinary chase-camera gliding, carving and diagonal
  riding, at slow and fast speeds. Include repeated crossings of the old 4 m
  thresholds, corners, threshold reversal and a stationary hold. Nearby fresh
  relief and loaded ski impressions remain clearly visible.
- [x] Check smooth slopes and uneven snow/rock transitions on the current
  Standard mountain, seed 849205174, using a compatible cached fixture through
  `tests/validation_mountain.gd`. Include bright midday, low sun and overcast;
  test presets 7 and 10, deformation off and an explicit on override at a lower
  preset. Inspect native and supported temporal upscaling for shimmer/ghosting.
- [x] No holes, rectangular shading/shadow jumps, texture swimming, track
  displacement, doubled terrain, reset streaks or stale patch on quality changes.
  Validate continuity at fixed world points across recenter events in a focused
  fixture, including atlas margins and terrain triangle boundaries.
- [x] Run `./scripts/validate_snow_contact.ps1 -Stage checks` (owns its guard).
  This includes native `tests/powder_upload_suite.gd`; retain byte-exact partial
  upload checks. Compile and exercise changed shaders on the native GPU.
- [x] Create `tests/local_snow_boundary_playtest.gd` or extend a suitable current
  fixture. Run through `./scripts/run_guarded.ps1 -FilePath ./godotw.ps1
  -Arguments @('--script','tests/local_snow_boundary_playtest.gd')
  -Label local-snow-boundary`; record the actual reproducible command if adapting
  another fixture. Capture the current baseline, not an unrelated historical
  snow-contact reference. Use isolated profiles and unranked runs; never write
  personal bests. Wait for the validation lock and do not nest guards.
- [ ] Compare warmed before/after screenshot-free timing at matched 4K output,
  preset 7, Auto/75%, frame generation off, with source/runtime/settings hashes.
  Report frame p95/p99, CPU/GPU time, uploads, dispatches and memory against the
  rendering policy. No material regression beyond measured repeat variability;
  repeat only when needed to resolve uncertainty. Short fixture timing does not
  establish full-descent performance.
- [ ] Keep physics/input/session code unchanged; if a necessary scope revision
  touches it, run required physics/runtime suites through the guard. Update the
  owning guide, validate backlog metadata, and commit/push owned changes and
  useful fixtures. Clean only task-owned unneeded artifacts under project policy.

Human acceptance: the user's assessment of subtlety during normal controller
riding is a separate follow-up, not a worker completion gate. Worker chronological
rendered inspection is required. Automated, rendered, performance and human
acceptance must be reported separately. All implementation checks above are
planned, not performed during authoring.

## Open questions

None.

## Completion record

Implemented the bounded local snow handoff and accepted scoped native review.
The 4 m storage grid is separate from the continuously rendered rider center.
Relief is full within8 m, zero at13 m, and meets complementary opaque ownership
at13.5 m. A zero-relief collar, shared triangle normals/depth/cloud interpolation
and world-coordinate mesh remove the snapped geometric/material handoff.
Reconstruction, support, bounds, centers and ownership publish together on the
render thread. Reset/teleport/quality changes invalidate history/ownership before
reopening. Rock/retained-terrain bounds, nearby relief, player/ghost marks, 32 m
extent and fixed mesh/atlas capacities remain. No physical terrain changes or
production GPU readback were added. Rendering owns the contract.

Parent `snow-contact-checks` passed129 contact,32 rock and13 native upload checks.
[Support-cache checks](../../artifacts/orchestration_20260912/boundary/SUPPORT_CACHE_REVIEW.md)
passed **24 exact-byte/query/invalidation +22 boundary +7 carving-GPU** assertions.
The accepted q7 Clear/Day [v3 review](../../artifacts/orchestration_20260912/forest/boundary_v3_review/NATIVE_REVIEW.md)
covers ordinary glide/carve and synthetic movement. The final v5 pair passed
**six cases ×450 rows/JPGs ×two modes =5,400**. Its all-row audit has findings[]
and exactly equal roots/cameras/skis/bases/FOV. Independent reviews cover all six:
[forest's low-sun/retained-edge/off review](../../artifacts/orchestration_20260912/forest/matrix_v5_review/NATIVE_REVIEW.md)
(424 selected images) and [boundary's on/carve/snow-reset review](../../artifacts/orchestration_20260912/boundary/FINAL_MATRIX_REVIEW.md)
(468 selected images and eight GPU snapshots). These are sampled pixels, not
5,400 individually inspected frames. q10 native dusk and q4 Cloudy Auto75 active
FSR4.1.1 on/off are included. Synthetic timelines have zero solver ticks; real
rides integrate1,800 ticks/15 seconds. Snow-reset frame30 has fresh nonzero relief
and exactly zero old in-atlas marks; frame59 has48 fresh retained stamps. R2 and
the exact-pose R4 gate are closed. The stationary-root pair remains rejected.

[Three warmed capture-free 4K pairs](../../artifacts/orchestration_20260912/finish/boundary_timing_review.md)
exposed an uncached snow/powder p99 rise to3.115–4.889 ms. The bounded1,296-byte
previous-grid cache queries9/17 new knots for axial/diagonal shifts and81 on
rebuild. Its one justified same-trace follow-up used **738 queries/5,904 reused
knots**, unchanged82 support uploads, and **0.814 ms snow/powder p99**
(mean/p95 .243/.533 ms). This addresses the measured query cost; it is not a new
three-repeat final-source comparison or sustained-FPS guarantee. Full-frame
repeat variability precludes a speedup/no-regression claim. The strict compound
timing checkbox remains open; the user's FPS waiver permits delivery with that
stated limit, not an invented pass.

R1 loaded scalloped banks remains open with the carving spacing caveat in
[world_shape/REVIEW.md](../../artifacts/orchestration_20260912/carving/world_shape/REVIEW.md).
Foreground/spray obscures some contact; softened temporal rider/ski/shadow fringes
occur in both variants. No new boundary-specific blocker was found. Frozen/current
crystal includes differ, while v5 compute hashes match: glitter changes are not
a boundary-only causal result. Captures contain C-pole/replay6/archive3; later
replay7/archive4 does not relabel them. No new tuning, idea or matrix is requested.

- [ ] Human normal/controller-riding judgment of subtlety: pending separate follow-up.
- [ ] Parent delivery: **PARENT TO FILL** commit(s), successful push, final status and artifact-lifecycle disposition. Status remains `in_progress` until parent delivery.

## Checkpoint disposition — 2026-09-12T13:21:47Z

Implementation is included in the user-requested integration checkpoint. Full original acceptance is not claimed. The manual workers were stopped at the user's request; no active claim remains. Further work is delegated to [AA-20260912-132147-review-loaded-track-ridge-shape](../completed/AA-20260912-132147-review-loaded-track-ridge-shape.md), [AA-20260912-132147-close-eight-feature-integration-records](../abandoned/AA-20260912-132147-close-eight-feature-integration-records.md). Do not redispatch this whole original task or repeat its completed matrices. The linked closure task owns final criteria reconciliation. Human acceptance and documented FPS/appearance limits remain explicit. Delivery is the Git commit containing this disposition; subsequent closure must record its own exact commit/push reference.
