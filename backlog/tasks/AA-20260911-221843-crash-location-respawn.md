---
id: "AA-20260911-221843-crash-location-respawn"
title: "Offer crash-location respawn from rest while keeping the race valid"
status: blocked
priority: P2
depends_on: []
created: "2026-09-11T22:18:43Z"
updated: "2026-09-12T13:21:47Z"
source_thread: "01a09289-665d-7721-a68f-81a220f4c751"
---

# Offer crash-location respawn from rest while keeping the race valid

## Outcome

Players can choose to recover near the location where a crash began and continue
skiing, instead of always restarting the descent. Preserve the user's instruction:
"Keep race valid but they should spawn with no speed." The user also selected
"Crash start; clock keeps running" with no extra fixed time penalty.

## Current state and evidence

Read-only source inspection on 2026-09-11 UTC at
`1c2c836bb0667bc8726c3097649bae843b17aeac`; no feature checks or rendered runs
were performed during authoring.

- [HUD](../../scripts/ui/hud.gd) `show_menu("crashed")` offers `TRY AGAIN`;
  `_primary_pressed()` dispatches the existing restart signal.
- [Main](../../scripts/main.gd) `_physics_process()` starts the crash ragdoll,
  sets `active = false`, and displays the crash menu. Its early inactive return
  currently prevents session time from advancing during the crash.
  `restart()` resets the simulation to race start or mountain spawn, calls
  `session.reset()`, and resets inputs, contacts, animation, camera and effects.
- [Simulation](../../scripts/core/ski_simulation.gd) `reset()` clears velocity,
  impact reserve damage, crash state and accumulated ride statistics. Reuse its
  physical reset contract while preserving appropriate attempt-level statistics.
- [RunSession](../../scripts/core/run_session.gd) owns time, first-crossing splits,
  eligibility, PB references and capture. `reset()` clears all of these attempt
  values; it is unsuitable for continuing the same race. `step()` can update
  splits and finish from a swept segment, so a recovery teleport must bypass it.
- [RunReplay](../../scripts/racing/run_replay.gd) is currently format 5. It expects
  120 Hz inputs matching the elapsed duration, uses 30 Hz articulated snapshots,
  and interpolates every adjacent sample pair. It has no crash/recovery event
  contract. Simply preserving the recorder across a time gap or teleport would
  produce invalid input counts or a ghost sliding through terrain.
- [RaceDefinition](../../scripts/racing/race_definition.gd) is currently schema 4;
  canonical race data and `record_identity()` identify comparable records.
  [CompetitiveRecord](../../scripts/racing/competitive_record.gd) atomically
  saves PB time, splits and replay. Current [Racing](../../docs/RACING.md)
  describes crash attempts as unable to replace a PB ghost; this rule must change.
- [Ragdoll](../../scripts/presentation/skier_ragdoll.gd) follows physical hips
  after onset. Their later position must not select the recovery anchor.
- No matching recovery task was found in tasks, archives or ideas. The completed
  [interface overhaul](../archive/AA-20260911-163058-interface-overhaul.md) owns the existing
  menu shell. The ready [weather/race task](AA-20260911-160307-weather-upgrade-storm-races.md)
  also touches race schema, identity and main lifecycle: coordinate these shared
  owners and allocate versions from current source rather than assuming schema 5
  is free. Neither feature logically depends on the other.
- The ready [animated ghost and tracks task](AA-20260911-220556-animated-ghost-snow-tracks.md)
  shares replay capture/format and ghost lifecycle. Preserve its production-pose
  payload if it lands first, coordinate format allocation, and break any ghost
  track emission across crash intervals and recovery jumps. No hard dependency
  is needed; recovery must work with the ghost presentation present at delivery.

## Agreed decisions and scope

- Add an explicit `RESPAWN HERE` crash-menu action, retaining `TRY AGAIN` as the
  full restart choice. Support free skiing and timed races, including the explicit
  laboratory fixture. Use existing controller/keyboard/mouse menu navigation.
- Anchor recovery at the authoritative crash-onset location. Ignore subsequent
  ragdoll travel. Use nearby supported terrain if the exact point is obstructed
  or unsafe; recovery must not become a shortcut or advance through a finish.
- Reset translational and rotational motion to rest, restore full impact reserve,
  and re-establish grounded ski/body support. Gravity and ordinary player input
  can accelerate the rider on subsequent ticks; zero speed is the reset state,
  not a persistent freeze or launch impulse. Use a stable downhill-facing stance
  where practical, with the captured heading as a fallback on nearly flat ground.
- Preserve the current attempt, elapsed time, already earned splits, frozen PB
  reference and prior eligibility. A previously eligible recovered run may set a
  PB and save its ghost. Recovery must never make an automated, modified-physics
  or otherwise ineligible run eligible.
- Race time continues during the crash and while choosing/recovering from it;
  there is no added fixed penalty and no reset or subtraction of elapsed time.
  Preserve the existing explicit pause/focus-loss policy. Incidental crash-menu
  subpages must not silently stop the recovery clock; genuine pauses suspend both
  recovery progression and its clock. The crash screen must show the running time.
- Preserve useful attempt totals such as peak speed and total airtime across
  recovery; clear transient physics/contact/animation state. Full restart still
  resets the complete attempt and selects the usual start and heading.
- Repeated crashes may use the same choice. Do not add lives, checkpoints,
  invulnerability, racing-line guidance, a recovery settings system or a penalty
  configuration UI. Keep automatic boundary/summit-return ownership intact.
- Human controller/play-feel acceptance is separately pending follow-up, not a
  worker completion gate. Automated and rendered evidence are required below.

## Implementation approach

1. Add a dedicated UI intent and main lifecycle recovery entry point; do not call
   full `restart()` and patch selected session fields afterward. Capture the
   crash-onset anchor once per crash and invalidate it on full restart, race/world
   changes, finish and boundary-return transitions. Reject stale/repeated actions.
2. Resolve recovery with the shared 4 m support/material and obstacle interfaces,
   including active race props. Use a deterministic bounded local search for a
   supported, clear skier-and-ski footprint. Prefer the exact anchor, then nearby
   safe support without forward race progress or crossing terrain barriers.
   Consider a nearby last supported pre-crash pose for cliff/airborne failures;
   do not project an airborne crash arbitrarily far down onto the valley floor.
   Record the chosen finite search bounds and clearance rules with fixture
   evidence. If no local recovery is valid, explain its unavailability and retain
   full restart rather than silently relocating to a remote point or looping.
3. Keep recovery timing and race progression in the Node-independent session at
   120 Hz. Main may dispatch a crash/recovery tick while ordinary skiing is
   inactive; that tick advances elapsed time regardless of eligibility without stepping the skiing
   solver, earning splits or testing a ragdoll/teleport finish. Account for the
   crash onset tick exactly once. Preserve split history and rebase previous
   rider position/time before the next normal tick so teleport distance is never
   submitted as a swept race segment. Prevent placement beyond an unearned finish.
4. Stop and detach the ragdoll, prime authoritative contacts and reset pose
   interpolation, camera, tracks, particles, sound, voice and haptic transients.
   Restore the selected riding view. Cancel pending jump/trick/steering actions
   and require the normal neutral/release gates, including when confirm overlaps
   a gameplay action. Reuse existing reset helpers where useful without coupling
   physical reset to a new race. No simulation or placement authority in the HUD.
5. Extend capture/decoding/playback to represent crash intervals and explicit
   recovery discontinuities on the same race timeline. Keep bounded storage and
   exact sub-tick finish semantics; distinguish inactive/crash ticks from ordinary
   riding inputs rather than inventing a continuous skiing trajectory. The ghost
   may be hidden during the crash interval and return at the recovery pose;
   reproducing the Jolt ragdoll is not required. Never interpolate over a recovery
   jump or discard an otherwise valid ghost just because a recovery occurred.
   Preserve the existing duration/overflow fallback independently. If animated
   ghosts/tracks have landed, reset their interpolation and emission origins at
   recovery, preserving their recorded presentation fields.
6. Version the changed recovery competition rules in canonical race/record
   identity, including the timed lab identity, and bump the replay format for
   changed data. Include the recovery rule in portable custom race definitions
   with strict validation. Use current unused schema/version values and update
   related fixtures together; reject incompatible data, without migrations or
   compatibility shims. Do not change normal ski forces or model version merely
   to label a session-rule change. Preserve concurrent weather schema additions.
7. Update [Racing](../../docs/RACING.md) as the authoritative recovery/timing/record
   contract, [Presentation](../../docs/PRESENTATION.md) for controls and recovery
   lifecycle, and [Architecture](../../docs/ARCHITECTURE.md) for changed identities
   or ownership. Record detailed evidence and unresolved human acceptance under
   ignored `artifacts/`, linking only relevant acceptance in
   [Validation](../../docs/VALIDATION.md).

## Acceptance and verification

- [x] Reproduce a crash in free skiing and an isolated timed race. Both crash-menu
  choices work by keyboard/mouse and simulated controller navigation. Recovery
  resumes near the captured onset even after the ragdoll travels elsewhere;
  full restart returns to the original start with a fresh clock.
- [x] At the recovery boundary velocity and angular motion are zero, reserve is
  full, contacts and pose are valid, and ordinary downhill acceleration follows.
  Holding confirm/jump/trick/stick across recovery produces no unintended action.
- [x] Exercise obstacle impacts, steep support, airborne/cliff crashes, active
  gate props, boundaries, repeated crashes and no-safe-location failures. Placement
  cannot skip a finish, grant a split or use distant ragdoll movement. Non-crash
  contexts, stale anchors, double activation and world changes cannot recover.
- [x] In deterministic fixtures, a known number of crash ticks contributes exactly
  that duration to race time, with no fixed penalty, lost tick or double count.
  Genuine pause/focus cases follow the existing policy. Menu subpages, ragdoll
  settling/freezing and repeated recovery do not reset the clock or its ownership.
- [x] A previously eligible crash/recover/finish can save a new PB, matching splits
  and a loadable ghost to a disposable record store. Existing ineligible reasons
  remain ineligible. Recovery preserves prior splits, reference PB and ride totals;
  full restart still clears attempt state. Personal records remain untouched.
- [x] Ghost time matches the full race, hides during crash if using the bounded
  presentation approach, resumes at the recovery boundary without interpolation
  across the jump, and reaches the exact finish. Test multiple events, malformed
  events, old identities, overflow and atomic save/load as well as clean runs.
- [x] Extend focused runtime/lifecycle/competitive/race/menu checks for these
  behaviors. Run required suites serially through the existing guard:

  ```powershell
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/physics_suite.gd') -Label recovery-physics
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/runtime_suite.gd') -Label recovery-runtime
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/rider_lifecycle_suite.gd') -Label recovery-lifecycle
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/competitive_suite.gd') -Label recovery-competitive
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/race_suite.gd') -Label recovery-race
  ```

- [ ] Under the same guard, capture and inspect chronological native evidence of
  crash menu/time, selection, zero-speed supported respawn and resumed skiing,
  plus saved ghost playback around recovery. Cover chase/first-person cameras,
  readable menu focus at small and normal output sizes, and no stray tracks,
  equipment, screen effects or persistent crash audio. Use current warm mountain
  fixtures and isolated preferences/records per the validation guide.
- [x] Document bounded recovery-query cost and actual fixture coverage. Separate
  automated, rendered, performance and human/controller acceptance; do not infer
  frame-rate or controller feel from headless checks or screenshots.
- [ ] Update owning guides, validate the backlog, and commit/push small owned
  milestones with exact verification and source references in the completion
  record.

Human acceptance: a real-controller playtest should assess option clarity, restart
feel, local placement and repeated crash recovery. Record it as pending unless
actually performed; it is a follow-up rather than a worker completion gate.

## Open questions

None.

## Completion record

Implemented same-attempt RESPAWN HERE at the captured crash onset, retaining
TRY AGAIN as full restart in free skiing and races. Deterministic local search
uses shared support/material/active props: at most34 candidates within8 m,
2 m maximum drop,6 m rise and40° support limit, with footprint/path/finish checks.
Unsafe or unavailable locations retain restart instead of granting a shortcut.
Recovery restores rest, impact reserve and contacts, clears held/transient input
and presentation state, and preserves splits, reference PB, eligibility and
attempt totals. Crash time advances at120 Hz without solver/race progression;
explicit pause/focus policy remains. Replay hides crash intervals and resumes
locally without interpolating the recovery jump. Racing and Presentation own
the lifecycle; model29/race schema6/recovery1 retain authored weather rules1.

The [final native receipt/review](../../artifacts/orchestration_20260912/crash/FINAL_VALIDATION.md)
passed **105 checks**, with all26 chronological frames reviewed cumulatively
(the last independent pass opened16 originals). The visible body/equipment
offset is cleared: all80 equipment submissions are current-frame, with maximum
final-skin attachment discrepancy0.127 mm after fixture render-order correction.
No production rig/Jolt retune was needed. Recovery is at0 speed/full reserve;
the disposable eligible race preserves480 inactive ticks, finishes at
**14.794407352889436 s**, and saves/reloads matching PB/splits and327 samples/poses.
Actual active-prop impact is separate; timed onset is injected, followed by
ordinary neutral descent and actual swept finish. Free-ski/menu/neutral/focus,
repeated/stale actions and ghost hide/local-resume pass. Prior normal/small51/51
receipts retain layout coverage; the final observer/pole revision was not
recaptured at small size. Snow/camera occlusion limits fine anatomy inspection.

That native receipt is **C-pole, replay6/archive3**; its combined guard exit1
belongs to pole failures, not the105 crash assertions. The later applied lossless
codec is **replay7 (nine inputs)/archive4**, rejecting old identities without
migration. Current central checks passed **exact-clock95, archive119,
crash-replay36, small-cache37**, and physics56/runtime192. The
[exact-clock receipt](../../artifacts/orchestration_20260912/carving/exact_clock/results.json)
preserves the historical one-ULP counterexample and verifies exact float64 clocks
through replay, records and cache; full-precision decimal JSON alone was not the
fix. These codec passes do not claim a new native capture or maximum-cache timing.
No repeat of unchanged crash105 is requested solely for the codec change.
Prior crash-core82/rider51/race67/competitive53 coverage remains revision-scoped.

Observed placement activation cost was1–34 candidates and0.211–12.021 ms, with
no per-riding-tick search; this is bounded fixture cost, not natural-mountain
percentiles or FPS. The native fixture suppresses audio/haptics, so the compound
render/listening item stays unchecked despite completed visual review. FPS
caps/misses are advisory. Preserve prior failures, source hashes and native/core
scope in the [final checklist map](../../artifacts/orchestration_20260912/forest/final_four_records/CHECKLIST_MAP.md).
Pole E fitting remains separately owned. No additional idea or crash fix is proposed.

- [ ] Human controller option/restart/placement/repeated-recovery feel: pending separate follow-up.
- [ ] Listening and hardware haptics: pending; muted fixtures establish neither.
- [ ] Parent delivery: **PARENT TO FILL** commit(s), successful push, final status and artifact-lifecycle disposition. Status remains `in_progress` until parent delivery.

## Checkpoint disposition — 2026-09-12T13:21:47Z

Implementation is included in the user-requested integration checkpoint. Full original acceptance is not claimed. The manual workers were stopped at the user's request; no active claim remains. Further work is delegated to [AA-20260912-132147-close-eight-feature-integration-records](AA-20260912-132147-close-eight-feature-integration-records.md). Do not redispatch this whole original task or repeat its completed matrices. The linked closure task owns final criteria reconciliation. Human acceptance and documented FPS/appearance limits remain explicit. Delivery is the Git commit containing this disposition; subsequent closure must record its own exact commit/push reference.
