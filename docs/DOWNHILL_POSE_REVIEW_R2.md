# Downhill pose correction

**Superseded:** the user rejected this pass's hands and pole placement. Its
passing grades did not establish acceptance. See the [R3 correction](DOWNHILL_POLE_CORRECTION_R3.md).

Request: improve Regular downhill, Tucking downhill and Deep tuck before jump
to at least 8.0 overall with no scored body region below 6.5. Hidden neck shape
is unjudgeable; clothing/model differences are not animation defects.

The supplied user feedback is dated 2026-09-09T17:11:18.166Z and refers to r1
evidence `498acecabc63d674257c2cab12719967ce6b80b9ab075e4b11e62b3c11f748ac`.
The original review and scores remain in
`artifacts/pose_review/revisions/20260909-r1/`. R2 retains a fresh before capture
and its source snapshot because the current rig and physics differ from r1.

## Accepted feedback

- Regular overall user grades: 4.0, 5.0, 6.0. Open the chest and look down the
  travel direction. Bring the hips/knees forward, flex the elbows, and carry
  the hands ahead of the waist. The first pose's trunk and head were described
  as "one of the worst offenders in the animation."
- Both hands need better wrist alignment, especially the right hand (2.0,
  2.0, 2.5). Move the arm chain rather than translating the wrist joint.
- Bring feet, skis and knees a little closer together. Keep boots rigid.
- Tuck user overall: 5.0. Knees should advance toward the toe line, chest/gaze
  should rise, hands should gather ahead of the chest, and poles should pass
  alongside the hips without clipping the body.
- Preparation panel 3 user overall: 3.5. Add a coherent spinal curve, lower
  the pelvis into tighter leg compression, advance knees, lift the gaze,
  gather hands ahead of the chest, and keep the poles clear of clothing.
- R1 preparation panel 3 is already airborne. The corrected review must retain
  this timing caveat and also show the last supported frame; a still image
  cannot justify changing jump force or inventing supported extension.

## Implementation and evidence

`downhill_posture.gd` authors connected parent-relative targets before the
existing 120 Hz cosmetic rotation tracker. `skier_full_motion.gd` blends these
through straight downhill, tuck and preparation and fits the visual pelvis
against the actual rigid boot frames. Source animation curves, physics, and
final skeleton writing retain their separate responsibilities.

The ski-center spacing is 0.38 m (0.19 m half stance), down from 0.44 m. This is
the actual support spacing, not a cosmetic foot offset, so physics/model 25 gives
it a distinct benchmark identity. Replay format 4 and terrain v14 are retained.
The ordinary grip envelope is 28 degrees swing / 55 degrees axial rotation.
Compact carry permits 80 / 90 degrees; on this rig without a forearm-pronation
bone, Hand includes that axial rotation. The glove stays at the connected wrist
and the pole stays in its palm frame. These are explicit artistic rig limits,
not a claim that a hidden reference wrist angle can be measured exactly.

The straight-downhill blend is tracked at fixed ticks and interpolated with the
pose. A turn reversal crossing zero steer therefore cannot momentarily replace
the banked pelvis with the entire ready stance. Existing carving, grabs, landing
and switch contributions retain their own expression.

Capture selection rejects obstacle contacts and more than 10 degrees of support
normal change during regular/tuck samples. This is a terrain/contact criterion,
not a selection based on the rendered pose. Preparation still shows the real
jump and support loss. The original r1 tuck-release frame is not a valid current
fixture because it now contains collision recoil.

The older turn anatomy test still used the removed binding spacer and expected
zero skin twist. It now checks the actual boot child and the established
18-degree knee-plane allowance, consistent with the current attachment/anatomy
suites and the previously documented binding correction.

New grades must be authored from the new final rendered skeleton and motion.
R1's assessment generator must not supply grades to a new capture. Automated
joint/attachment checks, reviewer grades, hardware performance and user skiing
acceptance are separate evidence.

## Final R2 result

The implementing reviewer's nine overall grades are 8.0–8.5. All three motion
grades are 8.0; the minimum of 171 scored regional entries is 6.5 (both hands
during early tuck entry). Nine hidden neck entries remain unjudgeable. These are
new Codex judgments, not new user scores or an independent external review.
The main remaining differences are wider compact pole spread, visible palm roll,
and entry hands that gather later than the untimed illustration.

The final hand carry blends between fixed ready and compact local rotations.
This replaces a per-tick grip search whose equivalent palm-roll solutions could
change abruptly as terrain and source motion varied. Both arm chains remain
connected; no wrist translation, pole detachment or second skeleton writer is
used. Compact hand centers are approximately 0.24–0.25 m apart in the plane test.

Evidence: `artifacts/pose_review/revisions/20260909-r2/`. It contains 552 final
production frames, three synchronized camera views, three 60 FPS videos, nine
graded cards, source/requested/final diagnostics and 119 verified source inputs.
Maximum frozen-bone reconstruction error is below 0.000001 m. Preparation card 3
links directly to the last supported frame 65; card 3 itself remains frame 66
after the physical jump at tick 133. Flight/recovery shown afterward is context,
not a new grade for those separate animations.

All ten suites in `regression-final/results.json` pass: physics, runtime, skier
anatomy, compact posture, ski attachments, skier motion, landing absorption,
rock terrain, planted snow and turn anatomy. The four animation/attachment
suites were rerun after the last grip refinement and all pass in
`regression-final-grip/results.json`. This includes actual shaft/hip/thigh
clearance, connected segment lengths, rigid bindings, cuff limits, rapid
steering transitions, source toggles, grabs and unchanged simulated trajectories
with animation enabled. The new stance is physics/model 25; the grip refinement
does not alter physics. No new 4K hardware benchmark or user skiing acceptance
is claimed.

To reproduce an unsealed new capture, run `scripts/capture_downhill_review.ps1`
with a new revision name through `run_guarded.ps1`, then freeze its inputs with
`scripts/pose_review/freeze_sources.py`. Author new grades after inspecting that
capture. `author_assessment_r2.py` is locked to R2's capture hash and must not be
reused to grade different poses.
