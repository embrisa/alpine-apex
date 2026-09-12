---
id: "AA-20260912-173304-weighted-small-landings-without-rebound"
title: "Give small landings weight and remove unintended rebound on uneven snow"
status: ready
priority: P2
depends_on: []
created: "2026-09-12T17:33:04Z"
updated: "2026-09-12T17:33:04Z"
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
  [animation CPU work](AA-20260912-105301-reduce-animation-cpu-cost.md).
  [Pole transitions](AA-20260912-132147-finish-pole-transition-validation.md) and
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

- [ ] Frozen baseline evidence reproduces the reported small-hop/uneven-snow
  defect, with exact input, surface/settings and causal trace. If it cannot be
  reproduced, record the limitation and missing repro instead of declaring fixed.
- [ ] On flat/gentle snow and the reproduced reachable rounded-bump cases,
  touchdown settles without a second flight caused solely by numerical/support
  rebound or a replayed jump. Report before/after relaunch counts, peak separating
  normal speed, second-flight duration/height and settling time per case.
  Any remaining departure has demonstrated terrain/input cause, not just a label.
- [ ] Native matched chronology shows prompt, proportionate downward body
  compression and a smooth return to riding. It does not pop upward, oscillate
  or repeatedly restart the landing pose. Compare final skis/body and chase/
  first-person views; preserve hands, poles, boots and clothing clearance.
- [ ] Deliberate release jumps, one-shot buffered jumps, true sharp lips/drops,
  rounded bumps, shallow/deep snow, one-ski/mixed rock support, switch, tuck/light
  steering and large clean/awkward landings retain their intended distinctions.
  Reset, contact priming and pause/resume clear or hold transient state correctly.
- [ ] Run affected contact, snow response/crush/grounding, jump/handling and
  landing-absorption suites. Run the mandatory complete physics/runtime suites
  for physics/input/session edits. A guarded baseline-independent check is:
  `./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/snow_grounding_suite.gd','--','--contracts') -Label landing-grounding-contracts`.
  Required core commands are in [Validation](../../docs/VALIDATION.md#execution).
  Validate deterministic current-model replay and incompatible-model rejection
  when physics changes; run only affected animation/equipment/camera regressions.
- [ ] Use serial guarded 15-30 second descents with a clean timed stop and
  disposable unranked preferences/records. Synthetic microfixtures may be shorter.
  Record actual ticks/duration and stop reason. No full descent is needed for
  this scope. Separate chronological capture from a short capture-free timing
  sample of changed solver/animation work; do not claim whole-route FPS coverage.
- [ ] Update [Physics](../../docs/PHYSICS.md), [Animation](../../docs/ANIMATION.md)
  and any other affected owning guide with durable changes; keep detailed evidence
  in task-owned artifacts. Record exact checks, source/engine identities, known
  unrelated failures and commit/push references. Preserve concurrent work and
  needed review evidence during scoped post-push cleanup.

Human acceptance: the user's judgement of landing weight, natural recovery and
controller feel remains a separate follow-up, not an unattended worker completion
gate. Automated, rendered, performance and human acceptance must remain distinct.

## Open questions

None

## Completion record

Pending implementation. Record the confirmed cause, delivered behavior, actual
verification and remaining acceptance, updated guides, commit/push references and
any separately proposed follow-up idea links. Authoring does not dispatch a worker.
