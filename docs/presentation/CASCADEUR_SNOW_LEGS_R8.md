# Cascadeur R8: snow pressure and leg response

**Latest: [R9 deeper carving](CASCADEUR_DEEP_CARVING_R9.md)** follows the request for about 17 cm
between boot heights at the deepest carve. The optional trial reaches 16.94 cm
during the strong-turn fixture; its fresh model-28 comparison uses R8 and R9
pressure profiles with the same R7 hands. Earlier sealed evidence is preserved.

The user said: **“The hands are okay but the is no feeling in the legs, there
should be some height difference between the feet while carving because carving
is the act of pushing one foot down hard into the snow while the other follows
along at the top of the snow.”** When offered a choice between leg motion alone
and physical snow sinking, the user chose **“Include soft-snow sinking and leg
motion.”** R8 implements that physical trial and retains the R7 hand pose.

Double-click **Play Cascadeur Snow Carving.cmd**. **Enter / A** drops in,
**A/D / left stick** carves, **C** changes camera, and **F9** switches the pressure
support on/off. Both F9 modes retain R7 hands. The overlay reports each ski's
pressure sinking in centimetres. The trial disables recording and eligibility
after every restart. Normal launch does not enable this pressure-support layer.
`./'Play Cascadeur Snow Carving.ps1' -QuickSlope` uses the laboratory slope.

[Video comparison](http://127.0.0.1:8769/comparisons/cascadeur-20260911-r8/review.html)
has a front leg close-up and full oblique/front/side views, six sequences, linked
playback, normal/half speed and a frame slider. The videos use the captured
**base model 27**, plus `cascadeur-r8-pressure-snow-v1` on the candidate side.
Concurrent snow/air-control work subsequently changed the live project to model
28. The launcher inherits the live solver; the frozen movies are not a model-28
comparison. See the separate current-compatibility receipt before extending any
model-27 measurements to later builds.

## What moves, and why

`tests/cascadeur_r8_playtest/simulation.gd` wraps each physical ski's existing
`snow_crush_contact.gd` instance with `snow_support.gd`. At the start of each
physics tick it approaches the ski's last completed load-dependent penetration,
including the existing speed-planing response. The contact sample then lowers
the supported ski within the loose-snow layer. All later probes read that same
state; queries never integrate it again.

Pressure sinking is capped at **12 cm along the support normal** and by snow
depth, fading from no effect at 2.5 cm depth to full capacity at 12 cm. Rock and
very thin snow preserve the ordinary contacts. Sinking approaches its target at
30 cm/s and releases at 22 cm/s. Existing bank crushing consumes the same depth
budget before pressure sinking. Hop/departure and restart clear the state.
F9 off releases the offset over time; it does not reset the current trajectory.

The loaded ski can therefore sit below the lightly loaded ski. R8 creates no
cosmetic foot offset: the existing ankle/boot attachment and constrained pelvis/
knee fitting respond to those physical positions. No second skeleton writer or
animation-driven forces were added. The only production hook added here is
`main.gd:create_simulation`, whose ordinary implementation returns the same base
simulation as before. Core forces and tuning are inherited rather than copied.

There is no new Cascadeur leg clip in this pass. R7's saved source and imported
upper-body layer are unchanged. This experiment addresses gameplay ownership of
ski heights; it does not establish a benefit from Cascadeur AI or justify adoption.

The qualitative skiing reference is PSIA-AASI's
[foot-to-foot movement article](https://thesnowpros.org/2023/02/32-degrees-how-foot-to-foot-movement-aids-turn-transitions/),
which discusses outside-ski pressure and independent lower-leg movement through
transitions. It is not a numerical calibration of snow sinking or a claim that
every carved turn must have one boot 10 cm lower. The trial follows measured
loads, including transient load transfers, rather than hard-coding an outside
foot from the steering input.

## Coordinate result

On the captured 22 cm snow fixture, the six-second left/right contact checks
reach **9.93/9.97 cm** difference in penetration along the snow normal. These are
contact-depth differences, not world-Y coordinates.

For `steering_right`, frame **54** (1.8 seconds into the input sequence):

| Measurement | Current contacts | Pressure support |
|---|---:|---:|
| Right boot mesh origin, world Y (m) | -12.112056 | -12.137108 |
| Left boot mesh origin, world Y (m) | -12.140494 | -12.259376 |
| Absolute boot world-Y separation | 2.84 cm | **12.23 cm** |
| Right/left knee flexion | 31.3° / 46.8° | 52.3° / 24.6° |

Boot origins are computed from the recorded rendered ski transforms and the
real `Equipment.BOOT_ORIGIN = (0, .017, -.15)` attachment. The trial adds about
9.38 cm of boot world-height separation at that sample. Slope, fore/aft ski
positions and ski orientation contribute to world Y as well as sinking. The
value varies with load, speed, terrain and snow depth; 10 cm is not a fixed
coordinate target for every deep carve.

A fresh model-28 coordinate probe, using the same frame-54 setup on the updated
live solver, measured **2.84 cm before / 12.65 cm after**, adding **9.80 cm** of
world-Y separation. Both remained grounded. Its source hashes were stable during
the probe. The 28 trial, 56 physics and 170 runtime checks also passed again on
the updated project. This is current mechanical compatibility evidence; the
full rendered comparison above remains model 27.

## Validation and limits

- Original model-27 run: **28 trial contact checks**, **56 physics checks**, and
  **170 runtime checks** passed. Trial checks cover exact disabled equivalence,
  firm/thin snow, bounded depth/rate, deterministic turns/reversal, pure queries,
  nonnegative load, jumps, landing, reset, F9 settling, no flat-ground energy
  gain or launches, and the shared bank/pressure depth budget.
- Two separate simulations received the same inputs and initial setup on a
  14° plane with 22 cm snow, 18 m/s initial speed and 120 warmup ticks. Six
  four-second sequences retain **726 frames per variant**. All remained
  supported without crashes. Physics is deliberately different between sides.
- The final fitted pose passes binding, fixed-grip, segment-length and existing
  cuff limits over all candidate frames. Maximum binding error is under
  0.016 mm and maximum grip error under 0.005 mm. These establish attachment,
  not animation quality or controller feel.
- Full three-view renders contain all 726 frames on each side. Author inspection
  covered every chronological front sheet, matched right-turn frame 54,
  tuck-transition frame 45, and candidate left-turn frame 54/reversal frame 108
  triptychs. The independent boot heights and knee response are visible. At
  extreme banks the legs can still read as a single inclined stance; this pass
  does not establish a preferred overall carving style.
- **Both full clothing audits fail** at `tuck_turn` frames 44 and 45, both poles,
  ten sampled intersections per frame. Candidate hit positions differ, but it
  adds no affected frames or sides. The other five cases have no detected shaft
  intersections. This existing tuck transition remains unresolved.
- The front leg crops omit upper-body and pole-tip clearance. No overhead
  detail pass, continuous-motion quality grade, independent review, controller
  acceptance or rendered-FPS claim is supplied for R8.
- Contact changes alter bank and recovery. In the reversal capture, at frame
  108 the bank differs by roughly 53° between variants. Matching inputs does not
  imply matching motion. The large late joint difference is partly physical
  trajectory/balance divergence, not a metre of new authored pose offset.
- The original normal-mountain playtest reached manual-input readiness with
  pressure support and R7 hands enabled, F9 off/on and restart checked, and
  recording disabled. This startup receipt is model 27; later live-model
  compatibility is recorded separately. User skiing preference remains open.

## Evidence and continuation

Source and recipes: `tests/cascadeur_r8_playtest/` and
`art_source/animation/cascadeur_carving_20260911_r8/`. Retained R7 GLB SHA-256:
`d543ee7a802c09ec5ca36c55d6378fb8a4e0cc064e86e808d60101238f8cb352`.
Frozen comparison: `artifacts/pose_review/comparisons/cascadeur-20260911-r8/`.
Frozen captures/renders: `cascadeur-20260911-r8-01-before` and `-after` beneath
`artifacts/pose_review/revisions/`. Each has 99 captured source files. Snapshot
integrity and later live-source drift must be reported separately.

`execution_summary.json` retains successful guards, the initial harness parser
failure, both failed clothing audits, startup results and current-compatibility
results. `coordinate_example.json` records the calculation above. Seals certify
file integrity only. Keep these revisions unchanged; recapture both variants
against the same new solver identity for any later model-28 visual comparison.

The next acceptance step is user skiing with F9 on sufficiently deep snow:
evaluate whether the foot-height change reads better, whether pressure transfer
feels responsive, and whether the altered bank recovery is desirable. Adoption
of this trial and of Cascadeur itself remain separate decisions.
