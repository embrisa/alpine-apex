---
id: "AA-20260911-220556-animated-ghost-snow-tracks"
title: "Add selectable top-time ghosts with animated skiers, distinct colors and snow tracks"
status: blocked
priority: P2
depends_on: []
created: "2026-09-11T22:05:56Z"
updated: "2026-09-17T01:06:06Z"
source_thread: "01a0927f-723e-7341-bfbc-e2ca1b449d1b"
---

# Add selectable top-time ghosts with animated skiers, distinct colors and snow tracks

## Archive update - 17 September 2026

The integration-closure follow-up was archived at the user's request.
This parent record keeps its blocked status and evidence; the retired
follow-up no longer owns further work. Resuming this record requires an
explicit scope and retry decision.

## Outcome

The user wants ghosts to "also have a model/animations and produce snow tracks"
and to have a color visually different from the player's. They also want multiple
ghosts of selectable top times for each race, choosing "Fastest 10; up to 10
selectable." By default, race against the fastest ten available compatible
recordings. Let the player select a subset. Every ghost should look like a
properly equipped, animated skier following its own recorded run, leave ski
tracks in snow, and remain distinguishable from the live rider and other ghosts.
The user additionally requires distance-based translucency that never makes a
ghost fully disappear: the minimum opacity is **15%**.

## Current state and evidence

Source inspected and refreshed on 2026-09-11 UTC; these are code findings, not
rendered or performance acceptance. The task remains unimplemented and ready.

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
  that presentation contract.
- [RunSession](../../scripts/core/run_session.gd) saves a recording only when an
  eligible finish beats the PB; its newest-20 history contains metadata only.
  `reference_replay` is frozen from `best_replay` at reset. There is no replay
  archive for slower top times and old history cannot supply missing recordings.
- [CompetitiveRecord](../../scripts/racing/competitive_record.gd) version 2
  atomically stores one replay, PB/splits and history. Current `MAX_BYTES` is
  32 MiB; Racing still says 8 MiB. Reconcile this source/documentation mismatch
  when implementing the new bounded multi-replay storage contract. Simply
  multiplying the current document and eagerly decoding ten replays is not
  established as an acceptable memory/load-time design.
- [CompetitivePanel](../../scripts/ui/competitive_panel.gd) shows one PB ghost
  toggle and read-only history, and [HUD](../../scripts/ui/hud.gd) assumes one
  `reference_replay`. [Competitive tests](../../tests/competitive_suite.gd)
  exercise record promotion, bounded history, compatibility, ghost lifecycle
  and native playback; extend these contracts for multiple retained runs.
- Related work: [race-loop acceptance audit](../abandoned/AA-20260911-153905-race-loop-acceptance-audit.md)
  was retired before execution at the user's request; this feature task retains
  its own verification requirements.
  [Carving lean](../abandoned/AA-20260911-161450-proportional-carving-lean.md) and
  [pole pushing](AA-20260911-183812-slope-limited-pole-pushing.md) touch animation
  ownership. No hard dependency is needed: consume the production pose available
  when implemented and coordinate shared files without editing worker-owned tasks.
  [Crash-location recovery](../abandoned/AA-20260911-221843-crash-location-respawn.md) also
  changes eligible replay timelines. Preserve its crash/recovery discontinuities
  if it lands first; every ghost must break interpolation/tracks across its own
  recovery interval. This task does not independently change crash eligibility.

## Agreed decisions and scope

- Retain the fastest ten completed, eligible, compatible replay-bearing runs
  for each race, independently of the last-20 recent-results list. Include
  qualifying non-PB finishes; retain an older fast run even after it ages out of
  recent history. This is the local player's per-race archive, not an online
  leaderboard, multiplayer or imported-friend-replay feature.
- The user's selected default is **fastest 10**, with **up to 10 selectable**.
  With fewer recordings, show all available; with none, show a useful empty
  state. Select the fastest replay-bearing entries, skipping missing, malformed
  or incompatible payloads without inventing ghosts for old time-only results.
- Add an automatic-fastest mode and a manual subset selector in the existing
  race Records interface. Default to automatic; recompute its fastest available
  set at the next attempt after new eligible finishes. Manual selection may be
  empty and persists per race across retries/app reloads using stable run IDs.
  A selection change applies on the next start/retry, visibly labelled as such;
  never replace active competitors mid-run. The existing global ghost toggle
  remains an immediate hide/show switch and does not erase the saved selection.
  If a manually selected entry is evicted or unavailable, remove it with a clear
  notice rather than silently selecting another run. Returning to automatic
  explicitly restores fastest-time selection.
- Show each entry's rank, time, date and a matching ghost color swatch, with
  accessible controller/keyboard/mouse selection and a selected-count summary.
  Order by exact stored finish time, then a stable date/run-ID tie break. Distinct
  equal-time runs may coexist; the same run must never be duplicated. Color
  complements the textual run identity rather than being its only indicator.
- All selected ghosts begin at race time zero and share the session clock,
  independently stopping at their own recorded finish. PB split/finish deltas
  continue to compare against the PB frozen at attempt start, regardless of
  which ghosts are selected. Retention and selection do not change race rules.
- Replace the primitive PB silhouette with the existing full skier model and
  equipment, animated consistently with the recorded rider's actions. Cover
  ordinary skiing, tuck, turns, jumps, air rotation/grabs and landing; do not
  introduce a separate animation library or new character asset.
- Choose clearly contrasting ghost outfit colors from the player's current
  appearance. A fixed cyan choice is insufficient if the player is similarly
  colored. The implementer may choose the palette/contrast rule; maintain a
  stable run-to-color assignment while the selection/player appearance is
  unchanged and refresh contrast when needed. Distinguish all ten ghosts from
  the player and each other, keeping list swatches synchronized. Check the
  actual textured/lit result, not just RGB values. No color-customization menu
  is required.
- Replace the existing distance disappearance with smooth distance-based opacity:
  closer ghosts become more translucent, reaching a minimum of **15% opacity**
  (alpha 0.15, meaning 85% transparent), and become more opaque with separation.
  Distance alone must never hide an enabled active ghost, including exact overlap
  and distances beyond the old 750 m cutoff. Remove both the near-distance hide
  and far-distance hide; clamp the combined ghost fade to at least 0.15 for the
  body and all equipment. The implementer may tune the smooth curve/upper opacity
  for readability. Preserve ordinary depth occlusion and camera clipping; this
  does not add visibility through terrain. Explicit ghost-off and existing
  replay/session lifecycle cleanup remain separate from distance-based fading.
- Produce natural snow tracks from the replayed skis. Tracks use the current
  snow appearance rather than requiring colored snow. Snow spray, sound and
  additional environmental effects are outside this request.
- Remain presentation-only: no second skiing simulation, collision, forces,
  physical snow changes, ragdoll bodies, ghost gameplay input handling, sound, shadow or
  GI contribution. Preserve the 120 Hz solver, 4 m terrain authority, race timing,
  PB eligibility and player controls.
- Ghost off hides its model and tracks and stops emission. Re-enabling starts
  fresh track history at the current replay time, with no bridge or catch-up
  stamping. Near-player model fade alone does not suppress valid ski tracks.
  Pause freezes animation and emission. Finish stops new emission; existing
  tracks may remain under the normal bounded history policy until reset.
  Retry, replay replacement and world/race unload clear all ghost track history.
  Each ghost owns its own pose, finish state, materials and track histories;
  finishing or clearing one must not stop or erase another ghost's tracks.
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
   physics actor. Keep ghost histories independently resettable; compose all
   ghosts' and the player's GPU stamps without replacing terrain track bindings.
   Preserve grounded snow-only emission, live tip-to-tail alignment and breaks
   across unsupported skis, jumps, rock, teleports and replay discontinuities.
4. Isolate ghost material instances and implement the contrasting outfit/fade
   policy without modifying source assets, shared player materials or saved
   appearance. Apply the 0.15 minimum after combining ghost opacity/fade factors;
   do not accidentally multiply it below the floor with a second material fade.
   Reuse world lighting/quality settings. Avoid duplicate asset
   conversion, unbounded histories and allocation-heavy per-frame work.
5. Wire the lifecycle into the existing ghost toggle/session clock. Reset pose
   interpolation and per-ski stamp origins together on retry, time reversal,
   visibility re-enable or replay replacement. Bound animation/track work with
   measured optimizations that preserve the visible ghost and its 15% opacity
   floor. Do not use distance-based model culling as a performance shortcut.
   Prevent long connecting stamps across any skipped track updates.
6. Extend session/record ownership with stable run IDs and a sorted bounded
   top-ten replay collection. Keep best-time/split metadata and recent history
   distinct from replay availability. Admit qualifying non-PBs, evict the slowest
   retained replay when necessary, and prevent duplicate finish insertion.
   Snapshot the selected run set at attempt start. Persist automatic/manual mode
   and selected IDs per race without letting UI code own race recording/saving.
   Preserve visible save failures and atomic committed references; do not delete
   an old valid payload until its replacement is committed. Validate record-count,
   per-payload and aggregate bounds before allocation/decompression; decode only
   selected payloads as needed. Measure ten maximum-duration recordings for disk,
   loading and memory bounds. Bump storage/replay formats where required and
   replace superseded single-replay paths without adding compatibility shims.
7. Add the selector to CompetitivePanel through existing HUD/session intents and
   retained navigation patterns. Replace singular PB-only labels with accurate
   selected-count/status text while retaining the PB comparison meaning. Treat
   race switches, missing selections, global toggle, and independent finish/
   crash/recovery times as explicit multi-ghost lifecycle cases.
8. Extend focused regression fixtures and add a reproducible rendered ghost
   comparison harness. Update the authoritative race/render/animation guides
   only for their changed contracts; detailed captures and timings belong in
   ignored `artifacts/`.

## Acceptance and verification

- [ ] An isolated race retains its fastest ten compatible replay-bearing eligible
  runs across restart/reload, including qualifying slower-than-PB finishes and
  runs older than recent history. Exercise more than 20 completions, out-of-order
  times, ties, duplicate saves, eviction, save failure and separate race IDs.
  Automated/unranked/incomplete runs never enter the player's archive.
- [x] Default selection contains the fastest ten available (or all if fewer).
  Manual subsets from zero to ten survive retry/app reload; new bests update
  automatic selection only for the next attempt and do not overwrite manual
  choices. Missing/evicted selected IDs produce an explanation. Returning to
  automatic restores fastest selection. No selection leaks between races.
- [x] The selector exposes sorted rank/time/date/color and selected count; native
  controller, keyboard and mouse fixtures verify toggles, scrolling, focus and
  Back at supported small and 4K layouts. It clearly states that changed choices
  apply next attempt. Global hide/show preserves selection and starts no catch-up
  tracks. Actual human controller acceptance remains separately pending.
- [ ] Ten distinct ghosts play simultaneously from the same start clock with
  independent transforms, animations, materials and tracks. Different finish
  times, one invalid payload, and any supported recovery events affect only
  the relevant ghost. Live-rider physics, PB deltas and race results are unchanged.
- [ ] A valid isolated PB replay displays the full skinned skier and detailed
  equipment. Chronological captures show coherent entry/hold/release for tuck,
  both turn directions, takeoff, airborne rotation/grab and landing, including
  switch orientation. Hands/poles and boots/skis stay connected; motion follows
  the recorded rider, independently of the live player's current action.
- [ ] The ghost is visibly distinct with default, dark, light and cyan-like
  player outfits in bright snow and shadow, including all ten selected ghosts.
  List swatches match stable run colors. Changing the player's appearance
  refreshes contrast without modifying player materials/preferences. Near-player
  and first-person overlap remain translucent at no less than 15% ghost opacity,
  without detached opaque equipment or an invisible body.
- [ ] Automated opacity checks cover exact overlap, both sides of the old 1.2 m
  and 4 m thresholds, ordinary separation, and both sides of the old 750 m
  cutoff. Smooth opacity never falls below 0.15 and distance never sets an active
  ghost invisible. Native chronological captures inspect the same near/far
  transitions and ten overlapping ghosts, keeping the visible body/equipment
  consistent. Check clear sightlines within camera range separately from normal
  terrain occlusion, camera clipping, explicit ghost-off and replay cleanup.
- [ ] Both supported skis leave continuous snow tracks aligned with the rendered
  skis, including live fronts during hard turns. Unsupported/airborne skis and
  exposed rock leave no false marks. All ten ghosts' tracks and player tracks
  coexist correctly within explicit total CPU/GPU stamp and memory budgets.
- [ ] Focused automated coverage verifies per-ski contact decoding/interpolation,
  independent materials/history, pause, toggle off/on, retry/time reversal,
  replay replacement, finish, distance return and teardown. No connecting stamp,
  stale model, duplicate ghost gameplay input/UI, physics body or personal-record write
  survives those transitions. Automation uses isolated records/preferences.
- [ ] Replay encode/decode and malformed/incompatible data checks pass. Verify
  the chosen representation with ten full supported-duration recordings against
  documented per-replay/aggregate storage, decompression and memory bounds;
  preserve bounded overflow behavior and useful time-only results when capture
  is unavailable. Missing/incompatible entries must not block valid other ghosts.
  Confirm unchanged race timing, split/PB eligibility and exact finish behavior.
- [ ] Run relevant existing animation/equipment and snow-response/contact suites
  per the owning guides, plus `tests/competitive_suite.gd` and the rendered
  `tests/race_suite.gd`. Add focused ghost/selection checks with exact commands
  in the completion record. This task now requires session/storage integration,
  so physics/runtime checks are mandatory. Run serially as:

  ```powershell
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/physics_suite.gd') -Label ghost-physics
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/runtime_suite.gd') -Label ghost-runtime
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/competitive_suite.gd') -Label ghost-competitive
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/race_suite.gd') -Label ghost-race
  ```

- [ ] Inspect native chronological rendered evidence from the actual production
  path. Compare zero, one and ten animated ghosts, separating the added track
  cost on a matched route/settings/camera at current 4K target settings. Record CPU/GPU
  frame-time cost, rendered FPS, memory and bounded long-run track use separately
  from captures and generated frames, plus archive-load and memory costs.
  Address material regressions or report a precise blocker; silently lowering
  the user-selected ten-ghost capacity/default is not acceptance. Do not infer
  performance or visual acceptance from headless
  tests. All engine workloads use the existing validation guard without nesting.
- [ ] Update changed domain contracts, validate backlog metadata, and commit/push
  only owned source/tests/assets/docs. Record actual verification, evidence paths,
  remaining human acceptance and delivery commits.

Human acceptance: the user's in-game review of ten-ghost readability, selection,
animation and track appearance is a separate follow-up, not a worker completion gate. Required
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

## Checkpoint disposition — 2026-09-12T13:21:47Z

Implementation is included in the user-requested integration checkpoint. Full original acceptance is not claimed. The manual workers were stopped at the user's request; no active claim remains. Further work is delegated to [AA-20260912-132147-finish-ghost-selector-and-render-fixtures](../completed/AA-20260912-132147-finish-ghost-selector-and-render-fixtures.md), [AA-20260912-132147-reduce-cold-ghost-archive-load](../tasks/AA-20260912-132147-reduce-cold-ghost-archive-load.md), [AA-20260912-132147-reduce-ten-ghost-presentation-cost](../tasks/AA-20260912-132147-reduce-ten-ghost-presentation-cost.md), [AA-20260912-132147-close-eight-feature-integration-records](../abandoned/AA-20260912-132147-close-eight-feature-integration-records.md). Do not redispatch this whole original task or repeat its completed matrices. The linked closure task owns final criteria reconciliation. Human acceptance and documented FPS/appearance limits remain explicit. Delivery is the Git commit containing this disposition; subsequent closure must record its own exact commit/push reference.

## Selector and fixture completion — 17 September 2026

The user's backlog-completion goal resumes the narrow follow-ups. Selector
acceptance is now complete: Automatic fastest 1–10 (default ten), frozen active
roster, persistent manual/empty selections and 92 native input checks at small
and 4K layouts. Current archive/retry checks pass. The original fixture failures
were coordinate transforms, quad winding and the stage light layer, not a
production input defect. All six contact cases pass; final palette-only checks
pass 37/37 with real shadow darkening of 56.6%. All ten ghost colours were reviewed
against default, dark, light and cyan diagnostic outfits with production lighting.
The palette portion of appearance acceptance is complete; broader chronology,
occlusion and playback cost stay attached to their original evidence/follow-up.
No human acceptance or FPS gain is claimed. See the completed selector task for
commands, retained evidence and delivery note. Cold loading and ten-ghost playback
remain active; this parent is not yet complete.
