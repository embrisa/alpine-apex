---
id: "AA-20260912-173304-weighted-small-landings-without-rebound"
title: "Give small landings weight and remove unintended rebound on uneven snow"
status: done
priority: P2
depends_on: []
created: "2026-09-12T17:33:04Z"
updated: "2026-09-13T10:27:21Z"
source_thread: "01a096ab-35cf-76e3-b11a-44ff6cf61ca8"
---

# Give small landings weight and remove unintended rebound on uneven snow

## Outcome

The user reports that landings lack downward impact and sometimes bounce the
skier straight back into the air, which feels unnatural. They specifically
locate the problem in **small hops and uneven snow**. Landing should produce a
short, readable leg/body compression followed by a controlled return to riding.
Ordinary reachable bumps should avoid immediate touchdown rebound while allowing
occasional natural terrain departures. The latest agreed rough-snow target is
about 3.5 hops (three to four in bounded regression samples). The user now
prioritizes medium-lip airtime at speed while keeping snow resistance and
absorbed landings; the earlier one-hop and 2.5-hop targets felt too grounded.
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
  [animation CPU work](AA-20260912-105301-reduce-animation-cpu-cost.md).
  [Pole transitions](../abandoned/AA-20260912-132147-finish-pole-transition-validation.md) and
  [residual carving pose](AA-20260912-153317-fix-residual-carve-pelvis-lean.md)
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

Latest feedback: high-speed downhill skiing still feels too grounded and muddy
over medium lips. Aim around 3.5 rough-test departures while preserving landing
absorption. Model 34 trial is implemented and pushed as `c3b2a15`.

- [x] Rough world: four departures; obstacle-free companion: three, averaging
  3.5 across two distinct scenarios. Smooth snow remains grounded.
- [x] A 0.8 m / 16 m lip now gives .725/.900 seconds of flight at 120/160 km/h,
  then at least one second of supported recovery. A 0.3 m bank stays absorbed.
- [x] 983 checks pass, including full physics/runtime, jumps/drops, current
  steering, snow/impact/replay contracts and bounded landing/terrain checks.
- [x] Matched before/after side and current chase captures each match all 1,800
  headless ticks. Prior settings are frozen on the current solver. Human feel
  remains pending; no animation-clearance or scene-performance claim.
- [x] Existing stress driver and unrelated dirty work are preserved. Source,
  failed/intermediate checks, final evidence and comparison are retained under
  `artifacts/snow_retention_airtime_20260913`.

### Previous model-32 verification (historical)

The latest user feedback supersedes the one-hop target below: model 31 feels too
heavy. Model 32 softens eligible snow retention to 40%, preserving the terrain
fix and the earlier landing compression. Implementation pushed as `5374ce1`.

- [x] The same rough world fixture has two hops; its obstacle-free companion has
  three. Both complete 15 seconds without crashing. Smooth snow has zero hops.
- [x] Final 962 functional checks pass, including full physics/runtime, jump/drop,
  contact/energy/replay, landing recovery and focused snow-bank coverage.
- [x] Native side/chase captures match all 1,800 headless ticks. A verified retained
  model-31 baseline provides the comparison. Human landing feel remains pending;
  existing pole/clothing and ski/terrain overlaps are not declared fixed.
- [x] Evidence is retained in `artifacts/snow_retention_balance_20260913`.

### Previous model-31 verification (historical)

The user rejected the first presentation-only delivery and clarified that the
whole skier hops off particular terrain, while good snow/slopes feel fine.
The physical follow-up below supersedes the earlier unreproduced-contact scope.

- [x] Frozen detector reproduces four failures in the new terrain suite;
  corrected detector passes all 13. Concave and lateral normal changes caused
  false takeoff suppression of snow retention. Real convex profiles remain.
- [x] Two current 15-second mountain sections exercise rough and smooth snow.
  Rough world flights fall from five to one; first 14 seconds stay grounded.
  A contact-only comparison removes collision differences: five flights/2.742 s
  become one/0.617 s. Actual later lips still release; this is bounded evidence,
  not a promise of zero flight on every terrain or preservation of every path.
- [x] Required full physics/runtime and affected regressions pass 4,497 checks.
  Energy/reach/unilateral load, manual/buffered jumps, real lips/drops, snow banks,
  rock/mixed support, tuck, impact cost, lifecycle and current/old replay covered.
- [x] Native 210-frame before/after side and new chase captures match headless
  physics at all 1,800 ticks. All paired side frames inspected. Pole/clothing
  audits remain imperfect: 29 flagged frames before, 22 after, with changed
  timing. Those retained pose issues are not declared fixed or clearance-clean.
- [x] Updated [Physics](../../docs/PHYSICS.md#snow-contact-and-small-banks) and
  [Architecture](../../docs/ARCHITECTURE.md#current-identity), preserving the
  earlier landing animation changes. Model 31 rejects older recordings; replay
  format stays 7. User stress/performance driver and concurrent work preserved.
- [x] Retain baseline, final sources, traces, comparison and unresolved audit
  evidence. Native wrapper removes its own linked scaffold. Post-push cleanup
  is scoped to regenerable staging from this follow-up; detailed receipt records
  the earlier dated-output reuse and repaired landing-suite default.

Human/controller judgement of landing weight and recovery remains separate and
pending. No uncontended scene-performance or whole-route acceptance is claimed.

## Open questions

None

## Completion record

### First delivery, 2026-09-12: presentation only

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

### Physical contact follow-up, 2026-09-13

User clarification: the whole skier still hops on particular terrain, while
good snow/slopes feel fine. Implemented and pushed `7a06dfd` on `main`.
The old retention veto used full triangle-normal angles and absolute grade
changes, so cross-slope ridges and concave pockets were mistaken for lips.
The new detector uses signed 4 m along-travel height chords and suppresses only
convex breaks above the existing 10-degree threshold. Loaded snow, 28 cm reach,
the 3 m/s dissipation cap, rock/jump exclusions and physical force ownership are
unchanged. No global gravity, added downward force, speed restoration or terrain
flattening. Model 31 / replay 7; previous recordings rejected without migration.

Final checks: physics 56, runtime 192, jump 90, handling 84, tuck-contact 213,
landing absorption 155, rock 32, snow response 33, snow crush 3,582 across 648
banks, landing settle 21, terrain settle 13, grounding contracts 26: 4,497 pass.
Initial failures from the old model-string expectation and the shallow-crest
test requiring repeated departures were corrected and rerun. The latter now
checks one initial terrain departure followed by settled support.

The selected rough section's real-world airtime changes from 2.55 to .133 s,
but later collision encounters differ. The separate obstacle-free contact
comparison changes 2.742 to .617 s, with exit speed 146.12 to 134.45 km/h (-8%).
This is a rough-section tradeoff, not a global speed or FPS claim. All 18 bounded
mountain scouts, their crashes and remaining true drops are retained. Smooth
snow keeps support. Native motion uses actual heightfield/obstacle responses
and production skier/camera, with scenery meshes omitted. Pose audit flags fall
29 to 22; clipping remains unaccepted and is preserved in both complete audits.

Evidence: `artifacts/snow_settle_20260913/RESULTS.md`, `delivery.json`, `before`,
`profile`, `contact_before`, `contact_after`, `contracts`, `baseline_contracts`,
`regression*`, `landing_final`, `grounding_contracts.json`,
`snow_crush_contracts.json`, `native_before`, `native_after`, `native_chase`,
`native_comparison.json`, `before_after.mp4`, `review_sheets`, `baseline`,
`final_source` and `guard_receipts`. Source hashes and the dated-output reuse
limitation are explicit. No independent/human acceptance or new task was created.

### Softer retention follow-up, 2026-09-13

User feedback: the one-hop result feels too harsh and weighted down; aim around
2.5 hops. `5374ce1` implements `snow_contact_strength=0.4` in script/default tuning,
leaving part of eligible separating velocity instead of absorbing it all. Model
32 rejects older recordings; replay remains 7. No hop quota or added force.

Ten strengths were scouted with ordinary inputs in both world/contact-only
variants. Final rough-world hops/airtime: two/1.508 s; contact-only: three/1.550 s.
The contact-only exit speed rises from 134.45 to 143.35 km/h (+6.6%). World exit
speeds meet different obstacle paths and are not a causal speed comparison.
The two variants average 2.5 departures but are not identical repeat trials.
Smooth snow stays grounded. Shallow repeating crests may give separated hops;
checks require bounded airtime/height and reject immediate touchdown rebound.

Final passing coverage: physics 56, runtime 192, jump 90, handling 84,
tuck-contact 213, landing absorption 155, rock 32, snow response 33, terrain
settle 17, landing settle 21, grounding contracts 30, crush contracts 18 and
quick crush 21: 962 checks. Full 648-bank matrix not rerun for this scalar tuning.
Initial old-strength assertions and a quoted-argument harness repair are recorded
in RESULTS.md alongside the passing reruns; no failed receipt is relabelled.

Both native views have 210 frames after eight seconds of ordinary-input lead-in.
Final source hashes are stable and all 1,800 physical rows match headless output.
The retained model-31 baseline's source bytes and 1,800 ticks match fresh baseline
scouting. All paired side frames and representative chase frames were inspected.
No animation source edits, new pole-clearance audit, FPS or human/controller
acceptance. Existing overlap findings remain. The stress driver is preserved.

Evidence: `artifacts/snow_retention_balance_20260913/RESULTS.md`, `verification.json`,
`baseline_native_identity.json`, `native_comparison.json`, `before_after.mp4`,
`sweep`, `sweep_middle`, `terrain_final`, `landing_final`, `regression`, contracts,
`native_after`, `native_chase`, `review_sheets`, `baseline`, `final_source` and
`guard_receipts`. Comparison retains `artifacts/snow_settle_20260913/native_after`.
Post-push cleanup only removes regenerable comparison frames and duplicate guard
history copies under the new task root; final review evidence remains retained.

### Medium-lip airtime trial, 2026-09-13

The user described high-speed support as muddy and medium lips as lacking air,
while stressing that snow resistance and absorbed landings must remain. They
requested a next target around 3.5 hops. Pushed implementation `c3b2a15` reduces
snow_contact_strength .4 to .3 and convex lip threshold 10 to 8 degrees. Existing
snow friction, suspension/rebound damping, crush and force ownership remain.
Model 34 rejects model 33 recordings; replay remains 7. No gameplay hop quota.

Current-branch baseline b5ed456 already includes model-33 steering and diagnostic
cases. Ordinary 15-second rough-world/contact-only samples give four/three
departures (1.925/2.908 s air), respectively, versus two/three (1.508/1.550 s).
One world departure is only .042 s; these are physical support-loss counts,
not identical-sized hops. World obstacle paths differ, preventing causal world
speed comparisons. The isolated medium lip changes from no flight to .725/.900 s
at 120/160 km/h, followed by continuously supported final seconds. Small banks
and smooth snow remain supported. The user's forced-speed driver is untouched.

All 983 functional checks pass: physics 56, runtime 192, jump 90, handling 84,
tuck/contact 213, landing absorption 155, rock 32, snow response 33, steering
snow 16, terrain settle 22, landing settle 21, grounding contracts 30, crush
contracts 18, quick crush 21. The periodic shallow-crest tests now check distinct
actual crest positions and bounded flight instead of suppressing subsequent
medium crests by a landing timer/count. The isolated lip, flat and smooth-hop
cases separately reject touchdown rebound. Full 648-bank matrix not rerun.

Source hashes remain stable for three 210-frame native captures, including the
preserved dirty pole-push source. Before uses frozen .4/10-degree assistance on
the current solver and matches the fresh baseline at all 1,800 ticks; after/chase
match final headless rows. All paired side frames plus chase frames 170/182/195
inspected. Existing overlaps remain visible; human/controller feel and scene
FPS are not accepted by these checks. The repeated-crest case is substantially
more airborne by design and still needs the user's judgement.

Evidence: `artifacts/snow_retention_airtime_20260913/RESULTS.md`, `verification.json`,
`native_comparison.json`, `before_after.mp4`, `baseline`, scouting and lip traces,
`terrain_final`, `landing_final`, `regression`, contracts, `native_before`,
`native_after`, `native_chase`, `review_sheets`, `final_source`, `guard_receipts`
and `delivery.json`. Cleanup is limited to regenerable comparison_frames under
this task root after push, with its actual outcome recorded in cleanup.json.
