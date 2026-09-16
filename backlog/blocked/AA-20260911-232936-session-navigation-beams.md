---
id: "AA-20260911-232936-session-navigation-beams"
title: "Place session-only navigation beams on the mountain map"
status: blocked
priority: P2
depends_on: ["AA-20260911-232811-taller-distant-finish-beam"]
created: "2026-09-11T23:29:36Z"
updated: "2026-09-13T20:38:41Z"
source_thread: "01a092cb-8276-7610-94d6-c817b99b24ed"
---

# Place session-only navigation beams on the mountain map

## Outcome

The user wants to "place marker beams on the map so it can help them navigate
down a line." Let the player survey the mountain, place several visual landmarks
along a chosen descent, and return to skiing with those beams visible in the
world. The user explicitly chose "Keep only for the current session" rather
than saving markers for each mountain.

## Current state and evidence

Inspected 2026-09-11 UTC (2026-09-12 local):

- [RaceWorkshop](../../scripts/racing/race_workshop.gd) supplies an overhead
  survey camera, pan/zoom, a terrain cursor and `pick_snow()`. Placement currently
  runs only in `mode == "create"` and creates race endpoints. The picker samples
  the authoritative field and rejects geology hits and race-zone exclusions.
- Workshop `close()` restores riding presentation and calls `show_race()`;
  `_clear_markers()` owns race visuals. Personal navigation markers need a
  separate lifetime so race previews, changes and retries cannot erase them.
- [main.gd](../../scripts/main.gd) selects the presentation camera and routes
  workshop input; its camera/UI/active-state branches currently recognize the
  race creation mode explicitly. [HUD](../../scripts/ui/hud.gd) exposes race
  library actions, not a dedicated personal map-marker tool.
- [Presentation](../../docs/PRESENTATION.md#ownership-and-navigation) and
  [Racing](../../docs/RACING.md#race-authoring) state that the existing endpoint
  survey pauses riding/session time and terrain placement is pointer-based.
  Controller menu navigation does not currently provide terrain picking.
- [race_beams.gd](../../scripts/presentation/race_beams.gd) is a reusable visual
  component, but its current boolean finish argument selects race-specific
  colors/brightness and every instance builds a fairly dense ground halo.
  Repeating that entire effect for many personal markers requires a cost review.
- No existing personal waypoint task was found in active/archived tasks or ideas.
  The [finish-beam task](AA-20260911-232811-taller-distant-finish-beam.md) is a
  dependency to settle the shared beam height/fade changes first. No gameplay
  implementation, rendered checks or performance measurements ran in authoring.

## Agreed decisions and scope

- Personal markers are session-only and never written to saves, race definitions,
  share codes, recordings or records. Keep them while retrying, returning to the
  summit, switching races or free skiing on the same loaded mountain. Clear them
  when switching/replacing the mountain or ending the application session. A
  same-mountain scene rebuild for a retry must not accidentally clear the list.
- Support multiple markers, with add, select, move, remove, clear-all and a
  show/hide control. Use a bounded maximum of 32 as an implementation default;
  display the limit when reached and never silently discard older markers.
- Use the existing rendered overhead survey as the map, reachable through an
  explicit Map / Navigation entry from summit and pause menus without creating
  or saving a race. Markers appear in this map and in the skiing world.
- Make personal beams visually distinguishable from lime start and amber finish
  markers, with map selection/numbering so players can identify their points.
  Exact color and height are renderer tuning choices. Preserve natural occlusion,
  translucency, weather integration and close-range readability. Avoid adding
  floating world text as a substitute for visible beams.
- Markers are optional visual landmarks. Crossing them adds no splits or gates,
  triggers no teleport, changes no eligibility/timing and never steers the rider.
  Keep placed markers until edited/cleared; no automatic disappearance on passing.
  No route solver, drawn ground racing line, new minimap, sharing or persistence.
- Keyboard/mouse supports direct placement and map pan/zoom. Provide deliberate
  controller reticle placement in this navigation tool as well as controller menu
  actions. Keep race endpoint picking outside this change. Respect focus scopes
  so menu actions cannot place markers, pan the map or move the skier by accident.

## Implementation approach

1. Add a session-owned list of finite, terrain-anchored positions with stable
   local IDs and bounded count; separate it from race marker cleanup and saved
   mountain data. Use the loaded mountain's full physical identity to avoid
   carrying positions across different mountains with the same seed. Choose an
   owner that survives same-mountain retries and document its teardown boundary.
2. Reuse/extract survey and terrain-picking helpers where useful. Separate raw
   terrain hits from race endpoint validation so personal points need supported
   playable terrain, not gate footprint clearance, race endpoint slope rules or
   40 m separation. Reject off-map/background/invalid hits with clear feedback.
3. Build a focused navigation panel using existing shell, focus and device
   prompts. Show existing points and the placement preview, provide clear edit
   controls and prevent clicks through UI. Controller terrain mode should use a
   visible reticle and explicit confirm/back; switching to a panel suspends map
   input. Back cancels a pending move before leaving the map. Leaving returns to
   the prior paused/summit context without starting a race or respawning the rider.
4. Integrate map mode into camera, pause, weather/audio and input ownership once.
   Opening the map during a run freezes session progression; resuming continues
   from the same state. Do not inject consumed map inputs into the next solver tick.
5. Reuse the dependency's height/fade solution through an explicit visual style
   API if needed, preserving start/finish callers. Give navigation beams an
   independent render owner and bounded geometry/overdraw. They may use a simpler
   base effect than race beacons. Reduced Motion and visibility toggles apply
   immediately without deleting points; test several beams visible together.
6. Document UI/lifecycle controls in Presentation and retain race invariants in
   Racing through a short cross-reference. Put detailed captures/timings in a
   dedicated artifacts directory; do not duplicate domain contracts.

## Acceptance and verification

- [ ] From summit and a paused descent, open Map / Navigation without entering
  race creation, place at least five points along a chosen line, and see them in
  the map and subsequent skiing. Move one, delete another, hide/show and clear
  all. Verify edits affect only the selected personal markers.
- [ ] Repeat the navigation workflow with mouse/keyboard and a simulated
  controller; inspect native rendered reticle/focus/prompts. Invalid terrain,
  clicks over controls, cancel, held buttons and device switching cannot create
  unintended markers or leak gameplay input. Reject marker 33 visibly.
- [ ] Points survive retry, return-to-summit, same-mountain scene rebuild, race
  changes and switching to free skiing. Switching to a different mountain clears
  them; relaunch starts empty. Demonstrate that no marker files or changes to
  saved mountain/race/replay/record identities are produced.
- [ ] The map freezes rider/session progression and returns to the correct prior
  context. A map-open/edit/close sequence preserves position, velocity, race
  progress and eligibility. Markers add no collision, crossings or split events.
- [ ] Inspect a chronological marked descent and fixed 500 m/2 km views on valid
  terrain. Exposed beams are useful from ordinary riding camera angles and
  distinct from start/finish, including with several visible at once. Inspect
  ridge occlusion, close passage, daylight/night and ordinary snowfall at
  Low/Balanced/High and 1080p/4K. Report actual distances and visual limitations.
- [ ] Measure the same scene with 0, 5 and 32 personal markers at near and distant
  views, with frame generation off and screenshot-free timing intervals. Record
  rendered frame/GPU cost and variance; resolve material regressions before
  completing. Avoid a per-marker terrain rebuild or large per-frame CPU loop.
- [ ] Add focused navigation state/input/lifecycle tests. Run them and affected
  interface/race tests via `scripts/run_guarded.ps1`; run mandatory physics and
  runtime suites for this input/session integration, for example
  `./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/physics_suite.gd') -Label navigation-physics`
  and the corresponding `tests/runtime_suite.gd` command. Run native rendered
  capture through the same guard, using isolated unranked fixtures and current
  cached mountains per [Validation](../../docs/VALIDATION.md). Wait for the lock.
- [ ] Update maintained guides, record actual verification and remaining human
  acceptance, and commit/push all owned source, tests and task completion changes.

Human acceptance: actual controller comfort and usefulness for navigating a
chosen line are separate user playtest follow-ups, not worker completion gates.
Worker completion requires automated integration checks plus rendered and
performance evidence; simulated input is not a physical-controller playtest.

## Open questions

None.

## Completion record

The [shared acceptance follow-up](../completed/AA-20260912-132147-finish-beam-navigation-acceptance.md)
completed its explicitly authorized functional/rendered pass on 2026-09-13.
Evidence: `artifacts/beam_navigation_acceptance_20260913/REVIEW.md` and its final
`regression-shared-final/`, `navigation-shared-final/`, `amber-shared-final/`.
The guarded batch passed 478 checks; native navigation passed 207; all 30 final
images were reviewed. Physics 35 / 120 Hz, world 15 / 4 m, race 6, replay 7 and
archive 4 are preserved. Concurrent grass/snow read inputs were pinned and
preserved, never staged by this acceptance task.

Five stable ordered landmarks persist through 1,800 ordinary-input ticks / 15
seconds. Map keyboard/pointer and simulated-controller flows, new-app empty state,
scene rebuild/mountain reset, nonzero race state/identity, retry/summit/free-ski
lifetime, marker bounds and personal data isolation pass. All five shader clocks
freeze/restore under Reduced Motion while steady shafts remain visible. 0/5/32
near/far views prove count/visibility only; close dense clusters overlap.

Still blocked: original screenshot-free same-scene 0/5/32 near/far frame/GPU cost
and variance remain unmeasured. The user explicitly excluded benchmarks during
this pass; functional count captures are not performance evidence.

Keep this parent blocked; do not redispatch it wholesale. The existing integration
closure task owns remaining criterion reconciliation. Physical-controller feel,
listening and subjective visual approval remain separate, unperformed human
follow-ups. Delivery is the commit containing development note
`changes/6764cc850279435984cbd8f4c0361ae9.json`; its full pushed hash/Dev ID is in
`artifacts/beam_navigation_acceptance_20260913/delivery.json`. Retain needed
evidence for unresolved original acceptance. No new task was dispatched.

## Checkpoint disposition — 2026-09-12T13:21:47Z

Implementation is included in the user-requested integration checkpoint. Full original acceptance is not claimed. The manual workers were stopped at the user's request; no active claim remains. Further work is delegated to [AA-20260912-132147-finish-beam-navigation-acceptance](../completed/AA-20260912-132147-finish-beam-navigation-acceptance.md), [AA-20260912-132147-close-eight-feature-integration-records](AA-20260912-132147-close-eight-feature-integration-records.md). Do not redispatch this whole original task or repeat its completed matrices. The linked closure task owns final criteria reconciliation. Human acceptance and documented FPS/appearance limits remain explicit. Delivery is the Git commit containing this disposition; subsequent closure must record its own exact commit/push reference.
