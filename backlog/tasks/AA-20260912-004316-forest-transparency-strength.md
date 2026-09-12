---
id: "AA-20260912-004316-forest-transparency-strength"
title: "Replace forest opening size with transparency strength"
status: ready
priority: P2
depends_on: []
created: "2026-09-12T00:43:16Z"
updated: "2026-09-12T00:43:16Z"
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

- [ ] Opening size is absent. Strength and Aid reach appear in the Forest
  visibility group with correct percentage values, help, focus and reset behavior.
- [ ] Strength 0/25/50/75/100% gives monotonically increasing removal at fixed
  reach after settling; 0% restores normal foliage and 100% matches the previous
  full-screen maximum. Corners and edges receive the same strength as the center
  for equivalent eligible foliage and depth. No screen opening remains.
- [ ] Reach and strength are independent. Either value at zero disables removal;
  changing one never overwrites the other. Save/reload, clamping/nonfinite input,
  reset-all, first-/third-person, preview, menu restore and teleport behavior pass
  in an isolated test profile without writing personal preferences or records.
- [ ] Resident/streamed/fallback foliage and quality/LOD switches keep the selected
  strength. Trunks remain readable; collision and forest population stay unchanged.
- [ ] Run the updated suites serially through the existing guard. Planned command
  template (use unique task-owned labels):

  ```powershell
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/foliage_sight_suite.gd') -Label forest-strength-sight
  ```

  Repeat for `tests/camera_profiles_suite.gd`, `tests/camera_suite.gd`,
  `tests/runtime_suite.gd` and `tests/graphics_suite.gd`. If physics, input or
  session behavior changes, also run `tests/physics_suite.gd` as required by AGENTS.
- [ ] Adapt the existing rendered review scripts to fresh output paths and run
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

Pending implementation. The worker should record the outcome, verification
actually performed, remaining acceptance, updated documentation, and commit/push
references. If blocked, record the blocker and unfinished work instead of success.
Link any separate next-step proposals in `backlog/ideas/`, or note that none were
proposed. Those suggestions require the user's selection before task authoring.
