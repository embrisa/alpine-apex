---
id: "AA-20260912-005323-subtle-local-snow-boundary"
title: "Make the moving local snow-detail boundary less noticeable"
status: ready
priority: P2
depends_on: []
created: "2026-09-12T00:53:23Z"
updated: "2026-09-12T00:53:23Z"
source_thread: null
---

# Make the moving local snow-detail boundary less noticeable

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
  [Raised-ski tracks](AA-20260911-225724-carving-raised-ski-tracks.md) and
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

- [ ] Matched before/after native clips show a substantially less noticeable
  advancing boundary during ordinary chase-camera gliding, carving and diagonal
  riding, at slow and fast speeds. Include repeated crossings of the old 4 m
  thresholds, corners, threshold reversal and a stationary hold. Nearby fresh
  relief and loaded ski impressions remain clearly visible.
- [ ] Check smooth slopes and uneven snow/rock transitions on the current
  Standard mountain, seed 849205174, using a compatible cached fixture through
  `tests/validation_mountain.gd`. Include bright midday, low sun and overcast;
  test presets 7 and 10, deformation off and an explicit on override at a lower
  preset. Inspect native and supported temporal upscaling for shimmer/ghosting.
- [ ] No holes, rectangular shading/shadow jumps, texture swimming, track
  displacement, doubled terrain, reset streaks or stale patch on quality changes.
  Validate continuity at fixed world points across recenter events in a focused
  fixture, including atlas margins and terrain triangle boundaries.
- [ ] Run `./scripts/validate_snow_contact.ps1 -Stage checks` (owns its guard).
  This includes native `tests/powder_upload_suite.gd`; retain byte-exact partial
  upload checks. Compile and exercise changed shaders on the native GPU.
- [ ] Create `tests/local_snow_boundary_playtest.gd` or extend a suitable current
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

Pending implementation. Record the demonstrated cause, adopted transition,
verification actually performed, baseline/after capture paths, performance,
remaining human acceptance, documentation and commit/push references. If blocked,
record the exact blocker and unfinished work. Link any separate ideas or note none.
