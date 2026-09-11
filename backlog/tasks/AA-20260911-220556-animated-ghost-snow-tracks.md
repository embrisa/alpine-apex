---
id: "AA-20260911-220556-animated-ghost-snow-tracks"
title: "Give ghosts an animated skier model, distinct color and snow tracks"
status: ready
priority: P2
depends_on: []
created: "2026-09-11T22:05:56Z"
updated: "2026-09-11T22:05:56Z"
source_thread: "01a0927f-723e-7341-bfbc-e2ca1b449d1b"
---

# Give ghosts an animated skier model, distinct color and snow tracks

## Outcome

The user wants ghosts to "also have a model/animations and produce snow tracks"
and to have a color visually different from the player's. A personal-best ghost
should look like a properly equipped, animated skier following its recorded run,
leave ski tracks in snow, and remain easy to distinguish from the live rider.

## Current state and evidence

Source inspected on 2026-09-11 UTC; these are code findings, not rendered or
performance acceptance:

- [PersonalBestGhost](../../scripts/presentation/personal_best_ghost.gd) builds
  translucent cyan primitive torso/head/limbs and box skis. It interpolates
  recorded joints but has no skinned character or poles. It hides within 1.2 m
  and beyond 750 m, fades between 1.2 and 4 m, and stops after replay completion.
- [RunReplay](../../scripts/racing/run_replay.gd) is currently version 5, with
  120 Hz inputs and 30 Hz snapshots. It records simulation facing joints,
  root/ski quaternions and per-ski grounded flags. `pose_at()` does not expose
  those per-ski flags; snapshots do not contain the complete production
  presentation pose, animation state or snow-response payload.
- [SkierVisual](../../scripts/presentation/skier_visual.gd) instantiates
  `assets/graphics/models/skier_v7.glb`, detailed skis, bindings, boots and poles.
  Its ordinary setup also creates a ragdoll and installs input/UI controls.
  [Animation](../../docs/ANIMATION.md) describes the authored/procedural pose
  composition and single final skeleton writer. Replaying simulation joints
  alone does not establish full production animation fidelity.
- [SkierAppearance](../../scripts/presentation/skier_appearance.gd) changes named
  materials and can save personal preferences. Ghost material changes must be
  instance-local and must not recolor the player or write those preferences.
- [SnowTracks](../../scripts/presentation/snow_tracks.gd) owns bounded retained
  stamps, live ski sections and GPU upload data. Its current input is simulation
  state plus [SnowResponse](../../scripts/presentation/snow_response.gd), whose
  contact/width/depth depend on per-ski support, load, slip and snow conditions.
  Merely projecting a ghost root onto terrain would draw false airborne tracks.
- [Main](../../scripts/main.gd) updates the ghost using interpolated session
  elapsed time and controls its visibility. [Racing](../../docs/RACING.md#recording-and-ghosts)
  explicitly documents the current silhouette with no tracks; this task replaces
  that presentation contract. Record payload/decompression limits are also
  documented there and must be considered before expanding snapshots.
- Related work: [race-loop acceptance audit](AA-20260911-153905-race-loop-acceptance-audit.md)
  audits existing behavior; this task implements the requested feature.
  [Carving lean](AA-20260911-161450-proportional-carving-lean.md) and
  [pole pushing](AA-20260911-183812-slope-limited-pole-pushing.md) touch animation
  ownership. No hard dependency is needed: consume the production pose available
  when implemented and coordinate shared files without editing worker-owned tasks.

## Agreed decisions and scope

- Replace the primitive PB silhouette with the existing full skier model and
  equipment, animated consistently with the recorded rider's actions. Cover
  ordinary skiing, tuck, turns, jumps, air rotation/grabs and landing; do not
  introduce a separate animation library or new character asset.
- Choose a clearly contrasting ghost outfit color from the player's current
  appearance. A fixed cyan choice is insufficient if the player is similarly
  colored. The implementer may choose the palette/contrast rule; maintain a
  stable color while the player appearance is unchanged and refresh it when
  that appearance changes. Check the actual textured/lit result, not just RGB
  values. No new customization menu is required.
- Preserve the existing near-player fade, depth occlusion and distance policy
  so overlap does not cover the rider or first-person view. The full model and
  its animation must remain legible at ordinary racing separation.
- Produce natural snow tracks from the replayed skis. Tracks use the current
  snow appearance rather than requiring colored snow. Snow spray, sound and
  additional environmental effects are outside this request.
- Remain presentation-only: no second skiing simulation, collision, forces,
  physical snow changes, ragdoll bodies, ghost input handling, sound, shadow or
  GI contribution. Preserve the 120 Hz solver, 4 m terrain authority, race timing,
  PB eligibility and player controls.
- Ghost off hides its model and tracks and stops emission. Re-enabling starts
  fresh track history at the current replay time, with no bridge or catch-up
  stamping. Near-player model fade alone does not suppress valid ski tracks.
  Pause freezes animation and emission. Finish stops new emission; existing
  tracks may remain under the normal bounded history policy until reset.
  Retry, replay replacement and world/race unload clear all ghost track history.
- A replay-format change is permitted if required for faithful presentation.
  Reject incompatible ghosts with the existing unavailable-ghost explanation;
  do not invent legacy poses or introduce migration/shim paths. Keep valid best
  times where the existing record contract permits.

## Implementation approach

1. Read [the animation skill](../../.agents/skills/alpine-animation/SKILL.md),
   [Architecture](../../docs/ARCHITECTURE.md), [Racing](../../docs/RACING.md),
   [Rendering](../../docs/RENDERING.md) and [Validation](../../docs/VALIDATION.md).
   Recheck current source and coordinate concurrent main/animation/replay work.
2. Introduce a bounded snapshot-to-presentation interface. Reuse the production
   character, fitting/equipment composition and final skeleton writer with an
   explicit ghost setup that has no player-only runtime side effects. Record
   the minimum completed presentation state needed to reproduce animation and
   equipment at the same session timestamp; do not resimulate recorded inputs
   or pass the live player's animation state to the ghost. Preserve interpolation
   and exact finish handling. Document pose sampling ownership/order and any
   changed format, validation, storage and compatibility rules.
3. Expose correctly timed per-ski contact flags and retain any additional compact
   track response data needed for faithful stamping. Use recorded ski transforms
   and read-only terrain/material queries. Share the track renderer through an
   appropriate presentation input interface instead of fabricating a second
   physics actor. Keep ghost histories independently resettable; compose both
   riders' GPU stamps without replacing the player's terrain track binding.
   Preserve grounded snow-only emission, live tip-to-tail alignment and breaks
   across unsupported skis, jumps, rock, teleports and replay discontinuities.
4. Isolate ghost material instances and implement the contrasting outfit/fade
   policy without modifying source assets, shared player materials or saved
   appearance. Reuse world lighting/quality settings. Avoid duplicate asset
   conversion, unbounded histories and allocation-heavy per-frame work.
5. Wire the lifecycle into the existing ghost toggle/session clock. Reset pose
   interpolation and per-ski stamp origins together on retry, time reversal,
   visibility re-enable or replay replacement. Bound animation/track work at
   distance and prevent a long stamp when returning from distance culling.
6. Extend focused regression fixtures and add a reproducible rendered ghost
   comparison harness. Update the authoritative race/render/animation guides
   only for their changed contracts; detailed captures and timings belong in
   ignored `artifacts/`.

## Acceptance and verification

- [ ] A valid isolated PB replay displays the full skinned skier and detailed
  equipment. Chronological captures show coherent entry/hold/release for tuck,
  both turn directions, takeoff, airborne rotation/grab and landing, including
  switch orientation. Hands/poles and boots/skis stay connected; motion follows
  the recorded rider, independently of the live player's current action.
- [ ] The ghost is visibly distinct with default, dark, light and cyan-like
  player outfits in bright snow and shadow. Changing the player's appearance
  refreshes contrast without modifying player materials/preferences. Near-player
  and first-person overlap fade still work without detached opaque equipment.
- [ ] Both supported skis leave continuous snow tracks aligned with the rendered
  skis, including live fronts during hard turns. Unsupported/airborne skis and
  exposed rock leave no false marks. Ghost and player tracks coexist correctly.
- [ ] Focused automated coverage verifies per-ski contact decoding/interpolation,
  independent materials/history, pause, toggle off/on, retry/time reversal,
  replay replacement, finish, distance return and teardown. No connecting stamp,
  stale model, duplicate ghost input/UI, physics body or personal-record write
  survives those transitions. Automation uses isolated records/preferences.
- [ ] Replay encode/decode and malformed/incompatible data checks pass. Verify
  the chosen representation against the full supported recording duration and
  existing storage/decompression bounds, and preserve bounded overflow behavior.
  Confirm unchanged race timing, split/PB eligibility and exact finish behavior.
- [ ] Run relevant existing animation/equipment and snow-response/contact suites
  per the owning guides, plus the rendered `tests/race_suite.gd`. Add focused
  ghost checks with exact commands in the completion record. Physics/runtime
  remain required for any input/session integration changes; run serially as:

  ```powershell
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/physics_suite.gd') -Label ghost-physics
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/runtime_suite.gd') -Label ghost-runtime
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/race_suite.gd') -Label ghost-race
  ```

- [ ] Inspect native chronological rendered evidence from the actual production
  path. Compare ghost off, animated ghost only and animated ghost with tracks on
  a matched route/settings/camera at current 4K target settings. Record CPU/GPU
  frame-time cost, rendered FPS, memory and bounded long-run track use separately
  from captures and generated frames. Address material regressions or report
  a precise blocker; do not infer performance or visual acceptance from headless
  tests. All engine workloads use the existing validation guard without nesting.
- [ ] Update changed domain contracts, validate backlog metadata, and commit/push
  only owned source/tests/assets/docs. Record actual verification, evidence paths,
  remaining human acceptance and delivery commits.

Human acceptance: the user's in-game review of ghost readability, animation and
track appearance is a separate follow-up, not a worker completion gate. Required
automated, rendered and performance verification must still be completed or
explicitly blocked; none substitutes for that human review.

## Open questions

None.

## Completion record

Pending implementation. The worker should record the outcome, verification
actually performed, remaining acceptance, updated documentation, and commit/push
references. If blocked, record the blocker and unfinished work instead of success.
Link any separate next-step proposals in `backlog/ideas/`, or note that none were
proposed. Those suggestions require the user's selection before task authoring.
