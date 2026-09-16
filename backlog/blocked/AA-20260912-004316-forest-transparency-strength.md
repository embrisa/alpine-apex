---
id: "AA-20260912-004316-forest-transparency-strength"
title: "Replace forest opening size with transparency strength"
status: blocked
priority: P2
depends_on: []
created: "2026-09-12T00:43:16Z"
updated: "2026-09-12T13:21:47Z"
source_thread: "01a0930f-61b9-7220-a2bc-66bd5f89dd9a"
---

# Replace forest opening size with transparency strength

## Outcome

Remove **Opening size** from Settings → Camera → Forest visibility and always
apply the aid across 100% of the screen, including edges and corners. Add
**Transparency strength** so the player controls how much nearby canopy is
removed while the existing **Aid reach** still determines the affected distance.

## Current state and evidence

Source inspected on 2026-09-12 at `7817856`; no engine runs were needed for
authoring, and all implementation checks below remain planned.

- [Camera settings](../../scripts/presentation/camera_settings.gd) currently store
  shared `forest_visibility` (reach, default 60%, range 0–100%) and
  `forest_visibility_size` (default 88%, range 20–100%). The
  [panel](../../scripts/ui/camera_settings_panel.gd) exposes both sliders.
- [Main](../../scripts/main.gd) passes these values through
  [AlpineAssets](../../scripts/presentation/alpine_assets.gd) to
  [FoliageSight](../../scripts/presentation/foliage_sight.gd). Its argument named
  `strength` currently changes depth, not removal intensity. Activation eases
  to one whenever reach is positive and the camera/riding state allows the aid.
- The [shader include](../../assets/graphics/foliage_sight.gdshaderinc) multiplies
  activation, a screen mask and a depth fade. At size 100% the screen mask is
  already bypassed. Its stationary threshold supports partial canopy removal;
  retain that coherent pattern through stacked foliage.
- Existing [visibility tests](../../tests/foliage_sight_suite.gd),
  [settings review](../../tests/foliage_sight_settings_playtest.gd),
  [forest review](../../tests/foliage_sight_playtest.gd) and
  [world review](../../tests/foliage_sight_world_playtest.gd) cover this path;
  replace their size-specific assumptions where present. Some write historical fixed output paths;
  change those to fresh task-owned paths before collecting evidence.
- Owning contracts: [Presentation](../../docs/PRESENTATION.md#riding-camera),
  [Rendering](../../docs/RENDERING.md#terrain-forests-and-lighting) and
  [Validation](../../docs/VALIDATION.md). Active/archived tasks and ideas were
  searched; no matching task exists. The completed interface overhaul established
  the current settings UI; no dependency is needed.

## Agreed decisions and scope

- Full-screen coverage is unconditional for this aid. Remove the size preference,
  slider, screen-window plumbing and replaced size-only paths within scope.
- Add a shared **Transparency strength** slider, 0–100% in 1% increments. Higher
  values reveal more through eligible nearby canopy. At 0% the aid removes no
  foliage; at 100% it has the existing maximum removal within the full-depth
  region, with the existing outer depth fade. This is canopy transparency, not
  global scene or whole-tree opacity.
- Use 100% as the initial/reset strength to preserve the previous maximum
  clearing behavior. This default is an authoring choice inferred from the
  existing behavior; the requested changes are full-screen coverage and a new
  independently adjustable strength.
- Keep Aid reach at its current range/default and distance mapping. Reach 0%
  disables the aid regardless of strength. Changing strength must not change
  reach, and changing reach must not change the selected strength.
- Apply changes immediately in both riding views and the settings preview, save
  through existing preference handling, and restore the new default on reset-all.
  Old size values must not affect the result; remove them from current output
  without adding a migration or compatibility shim.
- Preserve visible woody geometry, physical trees and collision, forest density,
  the 120 Hz solver, 4 m terrain authority, replay/record identity and eligibility.
  Keep the existing aid lifecycle for menus, camera switches and teleports.

## Implementation approach

1. Replace `forest_visibility_size` with a clearly named shared strength setting
   (for example `forest_visibility_strength`) in defaults, ranges, UI and wiring.
   Update help text to explain strength and reach, including their zero behavior.
   Keep existing preference validation and controller navigation conventions.
2. Pass reach and transparency strength as distinct values through the production
   path. Rename misleading internal reach arguments as appropriate. Remove
   camera-projected opening-center/radius calculations and the obsolete window
   uniform instead of retaining adjustable-size machinery fixed at 100%.
3. Scale canopy removal by normalized strength independently of the existing
   activation and depth fade. Clamp finite inputs defensively. Propagate current
   state to resident, streamed and fallback materials across LOD/quality changes.
   Preserve the opaque/dither rendering approach and stable threshold; inspect
   intermediate strengths for dense layered foliage and temporal artifacts.
4. Replace size assertions and captures with meaningful strength/reach behavior
   checks and refresh the owning guides. Do not describe planned evidence as a pass.

## Acceptance and verification

- [x] Opening size is absent. Strength and Aid reach appear in the Forest
  visibility group with correct percentage values, help, focus and reset behavior.
- [x] Strength 0/25/50/75/100% gives monotonically increasing removal at fixed
  reach after settling; 0% restores normal foliage and 100% matches the previous
  full-screen maximum. Corners and edges receive the same strength as the center
  for equivalent eligible foliage and depth. No screen opening remains.
- [x] Reach and strength are independent. Either value at zero disables removal;
  changing one never overwrites the other. Save/reload, clamping/nonfinite input,
  reset-all, first-/third-person, preview, menu restore and teleport behavior pass
  in an isolated test profile without writing personal preferences or records.
- [x] Resident/streamed/fallback foliage and quality/LOD switches keep the selected
  strength. Trunks remain readable; collision and forest population stay unchanged.
- [ ] Run the updated suites serially through the existing guard. Planned command
  template (use unique task-owned labels):

  ```powershell
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/foliage_sight_suite.gd') -Label forest-strength-sight
  ```

  Repeat for `tests/camera_profiles_suite.gd`, `tests/camera_suite.gd`,
  `tests/runtime_suite.gd` and `tests/graphics_suite.gd`. If physics, input or
  session behavior changes, also run `tests/physics_suite.gd` as required by AGENTS.
- [x] Adapt the existing rendered review scripts to fresh output paths and run
  with the same guarded command template without `--headless`. Inspect matched
  first-/third-person views at the five strengths, both screen corners and depth
  boundaries, plus chronological moving dense-forest and LOD-transition evidence.
  Check partial-strength dithering, temporal shimmer/trails and actual settings
  pixels. Injected keyboard/gamepad events do not establish hardware acceptance.
- [ ] Measure bounded matched dense-forest runs with strength 0/50/100 and fixed
  reach using current renderer/seed/camera/quality and independently warmed,
  capture-free trials. Report rendered frame times/FPS and any regression
  separately from screenshot evidence; do not reuse old forest performance.
- [ ] Update Presentation for player settings and Rendering only for shader
  ownership/behavior changes. Record actual evidence and remaining acceptance,
  validate backlog metadata, commit/push owned changes, and apply artifact
  lifecycle safeguards after preserving useful review evidence.

Human acceptance: the user's preferred transparency level and physical-controller
comfort are follow-up acceptance, not a worker completion gate. Required native
rendered inspection remains part of worker completion; automated checks alone
cannot establish visual quality or human preference.

## Open questions

None.

## Completion record

Implemented and parent-accepted for this concurrent run. Opening size and
screen-window plumbing are removed. Shared Transparency strength is 0–100% in
1% steps, default/reset 100%; independent Aid reach remains 0–100%, default 60%.
Both riding views and preview apply full-screen canopy removal; either zero
disables it. Preferences, menu/teleport lifecycle and resident/streamed/fallback
materials use the current setting without migrating old size data. Stationary
dithering, woody geometry, collisions, tree population and simulation authority
are preserved. Presentation and Rendering own the final contracts.

Parent-run evidence: **232 focused checks**, [430 native production-include mask
checks](../../artifacts/orchestration_20260912/forest/mask_1843922/report.json),
and [settings/preview failures=[]](../../artifacts/orchestration_20260912/forest/settings_16580_1216163/report.json).
The parent accepts the [11-result production-tree scene review](../../artifacts/foliage_v3/eight-forest-20260912/report.json):
five strengths in first-person/chase, backlighting, moving dense stand, quality
changes and fallback views. It shows increasing canopy removal with opaque wood;
the mask checks cover equivalent center/edge/corner depths and stacked layers.
The scene report explicitly has no player/solver session and three-second motion
clips; it is not an ordinary Standard-mountain descent. Central camera766,
graphics28/PC14 and physics56/runtime192 receipts supplement these checks.

Unchecked compound items remain honest: the named `camera_profiles_suite.gd`
receipt was not located in this audit; the other listed suite passes do not
silently substitute for it. No fresh capture-free 0/50/100 dense-forest timing
matrix is claimed. The user waived FPS caps/misses for the concurrent run;
screenshots and stand capture cost do not establish frame-time or full-descent
acceptance. This audit launches no extra validation scope.

Source/integration provenance is in [HANDOFF.md](../../artifacts/orchestration_20260912/forest/HANDOFF.md);
the final [checklist/evidence map](../../artifacts/orchestration_20260912/forest/final_four_records/CHECKLIST_MAP.md)
distinguishes passed components and outstanding record fields. No separate idea
was authored; preserve useful captures and prior failures for review.

- [ ] Human preferred strength and physical-controller comfort: pending separate follow-up.
- [ ] Parent delivery: **PARENT TO FILL** commit(s), successful push, final status and artifact-lifecycle disposition. Status remains `in_progress` until parent delivery.

## Checkpoint disposition — 2026-09-12T13:21:47Z

Implementation is included in the user-requested integration checkpoint. Full original acceptance is not claimed. The manual workers were stopped at the user's request; no active claim remains. Further work is delegated to [AA-20260912-132147-close-eight-feature-integration-records](AA-20260912-132147-close-eight-feature-integration-records.md). Do not redispatch this whole original task or repeat its completed matrices. The linked closure task owns final criteria reconciliation. Human acceptance and documented FPS/appearance limits remain explicit. Delivery is the Git commit containing this disposition; subsequent closure must record its own exact commit/push reference.
