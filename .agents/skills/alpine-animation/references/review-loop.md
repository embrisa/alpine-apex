# Diagnose, author, review

## Convert criticism into an observable question

Record action + phase + view + chain + defect. For example, “poles stick out in
tuck” requires measuring the whole shaft and tip, not just its distance at the
hip. “Elbows too wide” is a whole connected arm problem, not an elbow translation.
Keep the user's exact concern alongside your interpretation.

Inspect matched front, side, oblique and overhead views. Establish the initial
slope and camera scale before comparing spine angles or stance width. References
may be untimed, perspective-distorted or have a different body shape. A collar's
modelled neck shape can be unjudgeable as animation while neck/head orientation
is still assessable. Do not excuse a bad gaze as a mesh issue.

## A bounded iteration

1. Observe the final pose and neighboring frames. Locate the first phase where
   the defect appears. Record one causal hypothesis and the expected visible change.
2. Use `--diagnostic` to compare dominant source, requested and final views.
   Source good/requested bad points toward composition or targeting; requested
   good/final bad points toward tracking, limits, contact or attachment fitting.
   Diagnostic source/requested views pass through `present_authored`; they are
   explanatory reconstructions, not alternate production simulations. Confirm
   the conclusion against raw joints/rotations as well.
3. Change the owning stage for one coherent cause. Prefer state/phase-shaped
   targets and smooth release over global constants or permanent clamps.
   Keep rest lengths, connected rotations and rigid equipment authoritative.
4. Capture a small new attempt, select events and measure final results. Review
   selected stills first; run a selected clothing audit if proximity changed.
   Reject impossible or visually worse candidates early and record why.
5. For a promising candidate, inspect every chronological frame through entry,
   hold, release and neighboring actions. Run the full relevant clothing audit
   and regression suites. Selected stills alone missed R4 transition clipping.
6. Compare before/after with identical inputs/ticks/physics and controlled cameras.
   Watch normal speed and slow motion; inspect the actual gameplay view when
   changing runtime presentation. Update only the evidence you actually observed.

If repeated target changes do not fix the final result, stop blind parameter
sweeps. Trace the intervening constraint and inspect the offending frame/material.
“More clearance” in one location can drive a shaft through an upper arm elsewhere.

## Lessons retained from R1–R4

| Observation | Cause / useful correction | Status |
|---|---|---|
| R1 chest/gaze too low, wide stance, poor wrists | User corrections cover spine, knee advancement within rigid boots, stance and the whole arm chain | Rejected baseline |
| R2 mechanically plausible and author-scored highly, but poles still visibly wrong | Numeric passes and provisional author grades hid poor hip routing and hand alignment | User rejected; scores are not an acceptance baseline |
| R3 hip routing improved but tips still fanned out | Connected forearm pronation and fixed grip solved part of the problem; measure full pole silhouette too | Better direction, further correction requested |
| Tightening hands/elbows throughout R4 transitions caused jacket intersections | Sleeve and torso leave less room while chest rises; repeated soft limits move the requested shaft | Rejected intermediate attempts |
| R4 settles extra narrowing only near full compression | Slightly wider separated hands plus lower/backward targets, closer elbows and lower hip passage let straight shafts trail with less flare | Implemented, mechanically/render reviewed; final user acceptance pending |

The R4 held-tuck comparison at frame 106 reduced tip span from about 0.781 m to
0.655 m and shaft flare from 17.38° to 14.28°. Hands were slightly farther apart,
yet the **whole equipment silhouette** became narrower. These are case-study
measurements, not universal bounds or proof of an 8.0 grade. The R4 report records
552 chronological frames and a passing 426-supported-pose clothing audit.
See `docs/DOWNHILL_TUCK_ALIGNMENT_R4.md` and `docs/ANIMATION_REVIEW_LESSONS.md`.

## Mechanical and visual evidence

The clothing audit deforms actual skinned meshes from frozen final bones, then
checks a shaft centre ray and four offset rays at 6 mm radius from 10 cm below the
grip to the tip. It detects more than simple body capsules, but is a five-ray
approximation, not an exhaustive swept-volume or finger-contact certificate.
By default preparation coverage stops at physical support loss. For takeoff or
landing work, pass `-IncludeFlight` to the Audit stage and confirm that the report
records `include_flight: true`. Pass the desired scenarios explicitly and verify
their nonzero coverage; selected-frame checks alone do not certify the sequence.

Monitor elbow/hand spans, hand depth from chest, full shaft flare and pole-tip
span together. Also inspect root-relative stance, spine/gaze, knee/cuff angle,
attachment errors and frame-to-frame continuity. Smaller is not always better:
arms must open for carving and balance. Preserve the relevant action envelope.

For a requested overall ≥8.0 and no bone <6.5, assess **each requested action and
phase** and each judgeable bone/chain, not only an average across all frames.
Record the reviewer, evidence ID, status, score and a concrete comment. A low
wrist cannot be concealed by high foot grades. Unrated is incomplete; zero is a
real score; unjudgeable needs a reason and is excluded explicitly. Keep user and
model records independent. See [handoff format](handoff.md).

When available and relevant, obtain a fresh critic using the specified model on
the actual new evidence. Give it the rubric, camera/phase metadata and acceptance
constraints; ask it to identify worst offenders before assigning grades. Do not
ask it to “find reasons this passes.” If no independent reviewer is callable,
label your assessment as author review and leave independent grading pending.
Do not create an unsolicited separate task or claim a review that did not occur.

## Reference images when useful

Use the available imagegen skill when an additional bitmap reference clarifies
body-part placement; it is optional, not an iteration tax. For this rig ask for
the same skier/clothing/equipment proportions, neutral orthographic front/side/
overhead, the exact action phase, full-length straight poles and unobstructed
wrists/elbows/boots. Example intent: “deep straight downhill tuck, hands separated
slightly in front of chest, elbows near ribs, shafts outside hips trailing close
to the body, rigid boots, forward gaze; consistent pose across all views.”

Label the image synthetic, save its prompt and provenance, and visually inspect
anatomical consistency before using it. Never infer hidden 3D joint coordinates,
precise kinematics or a real skier's timing from a generated still. Prefer existing
adequate references and actual final-pose evidence over repeatedly generating art.
