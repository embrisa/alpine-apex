# Carving expression and physical response

Follow-up to `CARVE_JUMP_IMPACT_REVIEW.md`, 10 September 2026. The user rejected
the reduced carving-arm extension and reported left/right animation wobble when
steering changed faster than the skis responded. The prior a17 author grades
did not establish user acceptance; its sealed evidence and feedback stay intact.

The old source blend combined filtered steering intent with a subtracted body
bank. It could select the opposite turn clip on release or reversal while the
skis remained loaded on their existing edges. The new presentation input comes
from the load-weighted, completed edge angles of grounded skis. It controls clip
direction, balance/yaw targets and release of the straight-downhill pose. The
global requested `sim.edge_angle` is not a completed equipment response.

Carving now retains most of the authored shoulder/elbow motion: the fixed arm
target contributes 25% of the carving weight. The reviewed trunk support and
departure/impact targets remain, with the existing connected chain, anatomical
limits, rigid grip and final skeleton writer. Pose tracking still runs at 120 Hz;
there is no new input timer or solver write.

The new response suite exercises sustained left/right turns, rapid reversals,
100 ms taps and release. A separate simulator receives the identical input and
checks physical/replay equality. The before run reproduces 93 wrong-direction
clip samples in reversals and 78 in taps, plus eight premature commitments near
flat edging. Studio fixtures independently reproduce 52 and 46 opposite-clip
frames. These are fixture counts, not a frequency estimate for ordinary skiing.

Candidate `20260910-carve-response-01` passes all 22 response checks: zero
opposite-direction or premature clip commitments, unchanged physical runs and
at most 0.03522 m final-joint movement per tick across the four fixtures. The
before maximum was 0.03894 m; continuity remains bounded rather than frozen.

The matched studio capture has identical physics, inputs, ski transforms,
actual edge angles and loads across 1,572 frames in eight scenarios. Both use
model 27, v14 and the same engine. The 109 initially selected actual-clothing
checks pass. Selected renders show the extended balance arms returning in
both directions, and the tap sequence follows the physical edge transitions.
The full audit then rejected candidate 01: eight left-shaft intersections near
the inside knee at `prepare_takeoff` frames 176–183 during post-landing carving.
The other seven sequences pass. Selected evidence was not sufficient.

Candidate 02 keeps the existing hip passage active for a forward carving grip
until its lateral reach opens beyond the body. The old correction depended only
on preparation/landing phase, so it expired while the tracked hand still sat
ahead of the knee. This changes connected forearm/palm aim, not the restored
shoulder/elbow targets. Wide balance arms retain their free pole trail. Candidate
02 passes the full actual-skinned-clothing audit: all 1,572 frames, including
flight and every neighboring recovery frame, with zero shaft intersections.
The 22 response checks pass again, with zero premature or opposing clip samples.
All eight existing anatomy, compact-posture, attachment, motion, airborne,
landing, turn-anatomy and Steep-motion suites pass. These are the scoped
animation checks, not a claim that every project suite is green.

Author review covers every candidate frame chronologically in 45 front-view
contact sheets, plus selected full-resolution arm/equipment and
source/requested/final views. Both sustained carves recover their wide,
asymmetric gesture. Reversal and tap sequences stay with physical edging;
regular, tuck and jump/landing transitions remain coherent. The strongest
remaining stylistic limitation is the straighter, higher peak right-carve arm
and some stiffness through the central return. Existing takeoff pole windup
is still expressive and was not retimed in this follow-up.

The current model 27 / v14 gameplay export completes six unranked scenarios
without crashes: 606 poses and 1,212 chase/side images. Animation sources stay
stable throughout; takeoff and landing cases each record one landing. Gameplay
was sampled at regular intervals and phase boundaries, not inspected frame by
frame. Trees obscure some frames and the auxiliary side camera occasionally
passes below terrain. These views do not establish controller acceptance or
rendered frame-rate performance.

The paired review is
`artifacts/pose_review/revisions/20260910-carve-response-02/review/index.html`.
Its matched baseline is `20260910-carve-response-before`; candidate 01 retains
its rejection and failed audit. Capture sources, camera metadata, full
sequences, selected details, response results and author observations are
packaged with the candidate.

In the flat held-turn fixture (ticks 180–359), mean hand separation increases
from 0.791 to 1.076 m left and 0.796 to 1.063 m right. This measures recovered
extension, not quality. Before turn-clip weights peak at 46% left / 29% right;
at the strongest studio ski edging they fall to 6.3% / 1.8% respectively.

Initial 3.4 m camera framing clipped the extended right-carve arm. Frozen bones
are rephotographed at the same fixed 5.2 m scale for both versions, with 2.1 m
upper-body details. Pose, physical state and camera direction are not edited.
The full-frame projection check includes final bone points, pole ends and
approximate ski extents; actual images still require inspection.

No new numerical grade or user acceptance is asserted by these notes. Natural
counterlean that is present in the solver and physical skis remains visible.
