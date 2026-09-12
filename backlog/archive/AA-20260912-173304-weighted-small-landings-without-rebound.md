---
id: "AA-20260912-173304-weighted-small-landings-without-rebound"
title: "Give small landings weight and remove unintended rebound on uneven snow"
status: done
priority: P2
depends_on: []
created: "2026-09-12T17:33:04Z"
updated: "2026-09-12T18:18:58Z"
source_thread: "01a096ab-35cf-76e3-b11a-44ff6cf61ca8"
---

# Give small landings weight and remove unintended rebound on uneven snow

## Outcome

The user reports that landings lack downward impact and sometimes bounce the
skier straight back into the air, which feels unnatural. They specifically
locate the problem in **small hops and uneven snow**. Landing should produce a
short, readable leg/body compression followed by a controlled return to riding.
Ordinary reachable bumps should be absorbed without an unintended second hop.
Preserve intentional jumps and natural departure over genuine terrain lips.

## Current state and evidence

Source inspected 2026-09-12 at `23b8189d3ba61c07b9fb74f860ac00323b900e56`,
model 29 / replay 7. This is a player report plus source investigation; authoring
did not reproduce the bounce, run an engine workload or establish its cause.

- [SkiSimulation](../../scripts/core/ski_simulation.gd) applies snow retention
  before contact evaluation. `_update_contacts()` requires positive per-ski
  reaction within leg reach; loss of all support begins `unloaded` or `reach`
  flight. Soft recatch is restricted to recent unloaded flight, descending
  normal speed and no explicit airborne tilt/trick. Touchdown removes incoming
  normal velocity; subsequent contact/reach decisions can release again.
- [SnowContactAssist](../../scripts/core/snow_contact_assist.gd) dissipates
  separating velocity only with existing loaded snow support. Sharp local
  breaks suppress it; real jumps bypass it. [Snow response](../../scripts/core/snow_contact_response.gd)
  separately supplies compression/rebound spring and bounded damping forces.
  Investigate their ordering, shallow/deep snow, unloading and normal changes;
  these are hypotheses, not proof of excessive restitution.
- [Ski tuning](../../scripts/core/ski_tuning.gd) retains 28 cm leg reach, a
  0.18 s soft-recatch window, 2 m/s recatch closing-speed limit and 0.075 s jump
  buffer. Trace actual `jump_executed` before calling a relaunch spring rebound.
  Do not widen reach or remove the valid jump buffer as an unmeasured shortcut.
- [SkierAnimation](../../scripts/presentation/skier_animation.gd) observes
  per-ski and root landing onset, groups events for 0.30 s and budgets cosmetic
  drop after physical body compression. Its [tuning](../../scripts/presentation/skier_animation_tuning.gd)
  starts landing events at 0.75 m/s. Production [full motion](../../scripts/presentation/skier_full_motion.gd)
  also selects landing clips and fits the final pose. Check the final body and
  ski chronology; an event counter or requested pelvis offset is insufficient.
- [Landing absorption tests](../../tests/landing_absorption_suite.gd) primarily
  establish clean/rough reserve costs and contact episodes. [Snow grounding tests](../../tests/snow_grounding_suite.gd)
  cover ordinary ripples, jumps, lips and dissipative retention, but their
  comparison mode requires a frozen model-27 baseline. Passing that historical
  comparison would not establish this current landing fix. `--contracts` runs
  its baseline-independent contracts.
- No existing task directly owns this complaint. Preserve the completed
  [animation CPU work](../tasks/AA-20260912-105301-reduce-animation-cpu-cost.md).
  [Pole transitions](../tasks/AA-20260912-132147-finish-pole-transition-validation.md) and
  [residual carving pose](../tasks/AA-20260912-153317-fix-residual-carve-pelvis-lean.md)
  share presentation owners but have distinct defects; coordinate any overlap
  without absorbing or rewriting those tasks.

## Agreed decisions and scope

- Prioritize small-hop touchdown and repeated uneven-snow contacts. Include
  neutral riding, tuck and light steering; larger landings are regressions.
- Absorption remains automatic. Preserve existing forgiving clean-landing
  reserve behavior, including the small cost of extreme clean impacts. Added
  damage, timed crouch requirements or heavier haptics are not the requested fix.
- Physics owns physical settling; presentation reads completed state to show
  compression. Keep the Node-independent 120 Hz solver, two unilateral ski
  contacts and authoritative 4 m terrain/snow/material queries. No animation
  force, added downward kick, blanket grounded timer, tensile grip or root snap
  beyond existing hard-contact constraints.
- Preserve manual jump/air control, genuine lip/ledge release, switch symmetry,
  rock distinctions and ordinary tangential momentum. Do not flatten terrain or
  globally increase gravity to conceal this defect.
- Use existing body/landing presentation first. Inspect chase and first-person
  views; a correction to existing camera compression is in scope only if the
  matched repro identifies it as part of the defect. Respect effects-off,
  compression-strength and reduced-motion settings. No new shake effect or
  audio/haptic threshold retune is required.
- Keep current recording/session ownership. Advance model identity if physical
  behavior changes; reject/regenerate incompatible fixtures under project policy
  and audit current consumers instead of adding old-save compatibility paths.

## Implementation approach

1. Freeze the current relevant sources/settings and capture the smallest failing
   case. Reuse the real 4 m `SnowRipple` fixtures from
   [planted_snow_probe.gd](../../tests/planted_snow_probe.gd), then a short current
   mountain segment. Start with 30/60/120 km/h, shallow/deep snow and neutral/light
   steering; expand only when needed to locate the reported defect. Include a
   single deliberate hop followed by neutral input and natural small terrain
   gaps. Never reposition or inject velocity mid-case to simulate a fix.
2. Record completed-tick root/boot clearance, raw/support normals, per-ski
   reaction and normal speed, compression, assist correction/release reason,
   takeoff reason, jump input/buffer/execution, landing onset/episode, normal
   velocity after contact and duration/height of any second flight. Distinguish
   physical relaunch, legitimate geometry departure, pose recovery and camera
   motion. Keep at least one deterministic baseline failure for each fixed cause.
3. Correct the first responsible contact/damping/recatch or event/pose stage.
   Prefer bounded passive dissipation and coherent contact transitions within
   existing reach. Keep damping distinct from compressive load/grip. Do not
   suppress every unsupported frame: real lips, airborne motion and explicit
   jump input must retain their behavior. Test one-ski and mixed-material edges.
4. Make small but real impacts visibly compress knees/hips promptly and recover
   smoothly once. Scale response from actual normal impact/support, avoid
   double-counting physical compression, and prevent tiny recontacts from
   restarting an exaggerated takeoff/landing cycle. Review final production
   composition through contact, peak compression and recovery using the
   [animation skill](../../.agents/skills/alpine-animation/SKILL.md). Preserve
   connected limbs, rigid boots, fixed pole grips and the sole final pose writer.
5. Add focused regression coverage and a bounded capture route to existing
   landing/snow fixtures or a narrowly scoped new producer. Use fresh task-owned
   output paths; the older `landing_absorption_playtest.gd` hardcodes
   `artifacts/landing_v18` and uses a side camera with camera effects disabled,
   so it alone cannot prove current gameplay-camera acceptance.

## Acceptance and verification

Implementation was narrowed to the reproduced presentation cause. No physical
rebound was reproduced in the bounded ordinary-input cases; the solver remains
unchanged. The original player report is not evidence that every intermittent
physical relaunch is resolved. A remaining physical bounce needs its own repro.

- [x] Frozen baseline reproduces excessive small-hop hip dip/pop, missing
  additional procedural compression and restarted recovery. Four new focused
  checks fail against baseline and all 21 pass after the change.
- [x] Ordinary-input smooth/rounded snow at 30/60/120 km/h retains support after
  the intended landing; sharper angled terrain still allows actual departures.
  All 240 matched native sampled physical states are identical before/after;
  paired 120 Hz simulations also remain identical with/without animation.
- [x] Native final production motion shows proportionate compression and slower
  recovery. Side, uneven snow, chase and first-person captures inspected. All 34
  changed side-view frames reviewed. Clothing audit has no flags during changed
  landings; two side and six uneven pre-contact flags are baseline-identical.
  Those existing early poses are not claimed fixed.
- [x] Reset/pause, contact grouping and genuine new flight covered by the new
  suite. Anatomy, posture, equipment, flight and landing regressions ran. Total
  391/395 checks pass; four pre-existing animation/tuck failures reproduced on
  frozen baseline. No core physics/input/session edits, so complete physics and
  runtime suites, replay regeneration and a model bump were not applicable.
- [x] Four-second microfixtures plus an ordinary 1,800-tick/15-second current
  mountain segment completed with clean timed stops and no record writes.
  Uncontended timing was not assessed because the user was raiding in WoW;
  no whole-route FPS or performance acceptance is claimed.
- [x] Updated the owning [Animation guide](../../docs/ANIMATION.md#landing-compression-and-recovery).
  Physics ownership/behavior did not change. Preserved unrelated dirty files,
  including the user's immortal/high-speed stress driver. Source, checks,
  identities, known failures and review evidence recorded below.

Human acceptance: the user's judgement of landing weight, natural recovery and
controller feel remains a separate follow-up, not an unattended completion gate.
Automated, rendered, performance and human acceptance remain distinct.

## Open questions

None

## Completion record

Implemented manually at the user's request; no scheduled claim. Source, final
motion profiles, bounded capture tools, regression suite and owning guide were
committed/pushed to `main` as `64b57a1` on 2026-09-12.

Confirmed cause: pre-existing airborne crouch exhausted procedural impact drop,
while full motion played a normalized hard-impact pelvis pulse even on small
hops. The quarter-second recovery read as an upward pop. Capture physical flex
relative to touchdown, scale the full-motion response by impact depth, extend
small/medium recovery to 0.45/0.60 seconds, and prevent brief recontacts from
restarting the recovering pulse. Genuine jumps/sustained flight rearm it. Large
impact profile stays 0.85 seconds. No forces, support, reserve, body simulation,
input, camera effects, haptics, audio, terrain, model 29 or replay 7 changes.

Matched final-pose small-hop compression changes from 19.0 cm to 8.2 cm and peaks
125 ms after contact. Upward hip recovery changes from 1.483 to 0.322 m/s; 5.4 cm
compression remains at 250 ms instead of 1.3 cm. This is a measured correction to
visual landing recovery, not proof of human feel or a physical rebound fix.

Automated: landing_settle 21/21, skier_animation 47/50, skier_anatomy 84/84,
compact_posture 36/36, ski_attachment 20/20, skier_motion 18/19, airborne_pose
10/10, landing_absorption 155/155. The four baseline failures concern neck
counterbalance, tuck hand closure, large-impact spine threshold and 120 Hz tuck
hand easing. Native audit retains two side frames (14-15) and six uneven frames
(3-8) before touchdown; their geometry matches frozen baseline. These findings
remain visible rather than being waived as clean checks.

Detailed receipts: `artifacts/small_landing_20260912/RESULTS.md`, `delivery.json`,
`comparison.json`, `before_after.mp4`, `contracts`, `baseline_contracts`,
`before_probe`, `scan_results.json`, `mountain_before.json`, `regression*`,
`final_side`, `final_chase`, `final_first_person`, `final_uneven`,
`reference_side`, `reference_uneven`, `review_sheets`, `baseline`, `final_source`
and copied `guard_receipts`. Capture manifests preserve source/engine identities.
The 60 ordinary-input cases did not reproduce numerical rebound; 18 sharper
cases retain terrain departures. The actual current Standard mountain sample
(v15 seed 849205174, heading 0) has one deliberate jump and one landing in 15 s.

Post-push cleanup is limited to this task's temporary linked project scaffolds
and intermediate captures; final/baseline and unresolved review evidence remain.
Exact cleanup outcome is retained in `delivery.json`. No broad artifact cleanup.
Human playtest remains pending; performance acceptance was excluded during WoW.
No separate feature ideas or scheduled work were created.
