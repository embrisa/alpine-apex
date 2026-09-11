# Cascadeur R7 carving comparison

**Latest: [R9 deeper carving](CASCADEUR_DEEP_CARVING_R9.md)** follows the request for about 17 cm
between boot heights at the deepest carve. The optional trial reaches 16.94 cm
during the strong-turn fixture; its fresh model-28 comparison uses R8 and R9
pressure profiles with the same R7 hands. Earlier sealed evidence is preserved.

**Leg/snow follow-up:** the user found the hands acceptable but wanted different
foot heights and more leg feeling. They authorized soft-snow sinking plus leg
motion. [R8 pressure-support trial](CASCADEUR_SNOW_LEGS_R8.md) retains these R7
hands and adds a separate physical snow-contact comparison. R7's sealed evidence
below remains unchanged.

User direction: **“can we do carving and maybe make it sligthly different and see
if we like that more than our current?”** This follows the R6 playtest feedback,
**“they look very similar?”** R7 supplies a distinct, optional carving variant.
Preference and adoption remain open; no artistic score is assigned.

Double-click **scripts/launchers/Play Cascadeur Carving.cmd** in the project folder. It loads the
normal mountain with the candidate enabled. **Enter / A** drops in; **A/D / left
stick** steers; **F9** switches between current and Cascadeur carving; **C / right
shoulder** changes camera. The comparison button is accessible while paused or at
the summit. All runs are unranked. Normal launch keeps the production animations.
`./'scripts/launchers/Play Cascadeur Carving.ps1' -QuickSlope` opens the smaller laboratory slope.

## What changes

The candidate adds a modest upper-body counter-rotation and changes the arm
balance during loaded forward turns. The intended inside hand moves higher and
forward; the outside hand opens outward. In the final rendered strong turns,
both hands have a visibly higher, broader carry. Existing torso/arm motion still
participates, so the final difference is not identical to the isolated authoring pose.

The source is a two-second neutral/right/neutral/left/neutral pose sequence.
Gameplay reads the right and left extremes as local rotation offsets from neutral;
it does not repeatedly play that sequence against a timer. Loaded physical ski
edges choose direction and strength, including residual turning after input release.
The existing tracker smooths entry, reversals and the F9 comparison blend.

The layer peaks at 75% of the authored offset, with reduced weight for weak turns
and effective tuck. It is scoped by the existing carving action weight, which
releases for braking, preparation, flight, landing and backward travel. The test
does not replace those actions or import Cascadeur root motion. Straight travel
was exactly identical in the paired capture.

## Integration and source

`tests/cascadeur_r7_playtest/live_motion.gd` owns the optional layer. The only
production motion-code addition is the default no-op `refine_authored_pose`
extension point after action composition and before the shared anatomical limits
and 120 Hz tracker. The candidate applies local upper-body offsets there, keeping
the same pelvis/leg fitting, tracked pole aim and final skeleton writer. Its
authored body rotation is applied to the upper spine, leaving the supported pelvis
and legs under their existing gameplay targets.

The production animation library, original mesh/skin, equipment and physical solver
are unchanged. R6's ready/compression substitution is not enabled by this launcher.
The new scene inherits ordinary input/camera/session handling and disables record
eligibility after every restart.

Editable source and authoring receipts:
`art_source/animation/cascadeur_carving_20260910_r7/`.
The retained `carving_r7_animation.glb` SHA-256 is
`d543ee7a802c09ec5ca36c55d6378fb8a4e0cc064e86e808d60101238f8cb352`.
It contains 24 joints, 61 samples at 30 FPS and no meshes. Scripted targets were
solved through Cascadeur's established rig, saved, reopened and exported again.
Native AI Inbetweening and AutoPhysics were not used. This is a test of authored
carving variation, not evidence of AI authoring speed or superiority to Blender.

## Checks and evidence

- Source foot drift stays below 0.001 mm; maximum segment-length variation is
  0.0273 mm. Saved/reopened export position difference stays below 0.001 mm.
- Six four-second scenarios cover straight travel, light/strong left and right
  turns, reversals, quick taps and tuck/turn overlap: 726 paired frames. Physical
  state, ski transforms and recorded chase cameras match exactly.
- Candidate bindings, fixed grips and segment lengths pass; cuff forward/lateral
  angles remain within the existing checked bounds. Largest joint difference is
  16.16 cm in a strong turn. This is a maximum, not an average or a quality score.
- The focused 720-tick test checks solver invariance, exact disabled equivalence,
  a visible source contribution, return to production, reset and zero-action gates.
  All five animation suites pass: motion 19, anatomy 84, steep motion 77, compact
  posture 36 and ski attachment 20 checks.
- Full front/side/oblique renders retain all 61 source and 726 frames per gameplay
  variant. Selected overhead details cover entry, loaded turns, release and residual
  response. Comparison and audit receipts are stored with the review.
- The full pole/clothing audit **does not pass** for either gameplay variant:
  both hit clothing in `tuck_turn` at frames 44 and 45 (both poles, ten sampled
  intersections per frame). Candidate hit positions differ slightly, but it adds
  no intersecting frames or affected sides. The other five cases and isolated
  authored source have zero detected intersections. This existing transition
  defect remains unresolved and is not hidden by the passing binding checks.
- Author inspection covered chronological front sheets for every frame of all
  three revisions, matched strong-turn details and selected oblique/side views,
  the shared tuck-transition failure, and a matched chase-camera frame. Some hands
  and pole tips leave individual front/overhead crops at strong banks; those views
  cannot establish their full clearance. Continuous normal/half-speed videos are
  supplied for review; no independent motion-quality grade or preference is claimed.
- The normal-mountain launch reached a rendered, manual-input playtest with the
  candidate enabled. Its opt-in startup check exercised F9 off/on and restart,
  verifying record ineligibility. `artifacts/cascadeur_r7_live_playtest/ready.json`
  and `ready.png` retain the receipt and actual 3840x2160 startup image. This checks
  the harness, not controller feel or steady-state frame rate.

Revisions: `cascadeur-20260910-r7-source`, `-production`, `-gameplay` under
`artifacts/pose_review/revisions/`. Paired comparison:
`artifacts/pose_review/comparisons/cascadeur-20260910-r7/`.
The compact [local comparison](http://127.0.0.1:8769/comparisons/cascadeur-20260910-r7/review.html)
includes linked playback, half speed and frame scrubbing; `index.html` retains the
full selected-frame evidence. A 121-frame paired chase-camera clip uses the same
recorded cameras on the deterministic slope, with no mountain/scenery claim.
Guard logs use `artifacts/guarded/cascadeur-r7-*`. Runs were concurrent functional
checks, not rendered-FPS benchmarks. Controller feel and user preference remain
unverified until this playtest is reviewed.

## Rejected attempt and remaining question

Attempt 01 rotated torso controls around the lower spine while leaving the pelvis
orientation fixed; its export developed 2.13 mm of segment variation. Its fixed
hand helper locations also produced larger wrist rotation steps. It is preserved
under `attempt01/` and was not used in gameplay. Moving the coherent body controls
around the pelvis and moving hand orientation helpers with the hands resolved
those source defects. The original capture recipe also called an R6-only diagnostic
helper; that failed capture is retained in its guard log and is not a pass.

The remaining question is whether the more open arm carry feels preferable while
skiing. It can also read as more extended or stiff at strong banks. Evaluate that
tradeoff with F9 before adding more animations or changing the normal default.
