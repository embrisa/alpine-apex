# Arcade air control, model 27

The 120 Hz solver now gives strong rotation control while leaving gravity,
drag, jumping and linear momentum under their existing rules. Ordinary air
turning reaches 1.56 rad/s (89 degrees/s). Center the left stick after takeoff,
then forward/back requests continuous flips at 3.8 rad/s without L1/LB.
L1/LB plus the stick remains an optional shortcut for flips and 5.4 rad/s spins;
diagonal combinations share
a 7.2 rad/s ceiling. Acceleration is 36 rad/s², with 48 rad/s² release braking
and reversal. After a 40 percent aerial-response reduction, player feedback
restored just the flip rate to target about 1.7 seconds per turn from rest.
The reduced turning, spin and limited-pitch rates remain. Release brakes a
maximum flip in about 0.083 seconds with less than 8 degrees of remaining
rotation. The tuning checksum
separates the updated race/replay identity. This input remap retains the
eight-field replay v5 layout; `SkiSimulation.MODEL_VERSION` defines the active
physics model independently of the original model-27 air-control introduction.

Held stick tuck through takeoff cannot begin a direct flip: a centered stick
must first be observed in the air. Landing, pause, restart, focus loss and
controller connection changes clear this arming. Dedicated I/K and the optional
L1 shortcut remain deliberate immediate flip commands. The router receives
grounded state at 120 Hz and emits the existing resolved `air_pitch` intent;
input recording remains independent of router arming state.

Keyboard W/S or up/down requests limited pitch at 1.08 rad/s. Center that axis
after takeoff to arm it. Once armed, input adjusts attitude
within 50 degrees either side of its reference; release holds the resulting
angle and does not reset that allowance. After an explicit flip stops, that
attitude becomes the new reference and normal pitch requires neutral again.
I/K and Q/E remain direct flip/spin controls. Ground tuck, L2/LT braking and
R2/RT hold-to-prepare/release-to-hop retain their mappings. Tuck still affects
drag independently; comparison tests hold tuck equal when checking trajectory.

Whole-equipment rotation ownership is distinct from trick/flip history, so
ordinary turning and pitch carry the rider with the boots without selecting
a flip pose. Brief positive support recovery over ripples remains available
during ordinary yaw; intentional pitch and explicit tricks retain flight.
Quaternion integration retains vertical and inverted orientations.
Manual input overrides optional assistance, which remains off by default;
manual pitch and tricks hold their angle after release. Existing impact
reserve and incomplete-rotation landing consequences still apply.

`RiderInput.air_tilt` is signed limited-pitch intent. Replay v5 records it as
the eighth tick field, with validation and copy/read support. Model 27 and
default tuning hashes separate the new race identity; old replay layouts are
rejected without migration. Camera look and rendering do not write input,
rotation, momentum or records. Pause, menus and controller lifecycle gate
pitch independently from explicit tricks, preserving physical angular history.

## Verification

The focused suite covers flip directions/facing, repeated flips, release,
reversal, analog response, ordinary-pitch limits, handoffs, assistance and
recording. Required physics/runtime and affected controller, lifecycle,
competitive, jump, contact and animation suites accompany it.

`tests/arcade_air_playtest.gd` captures production v14 gameplay with the cached
default seed, ordinary hops, tilt, flips, combinations and landings. It stores
30 FPS chase/side sequences, source hashes, physical rotations and tick timings
under `artifacts/arcade_air_v27`. These are deliberately ineligible for records.
Capture overhead means these timings are not a 4K rendered-performance claim.
Automated evidence, rendered inspection and user controller acceptance are
separate; controller-feel acceptance requires actual play.

Run the automated group with `./scripts/validate_arcade_air.ps1`. It launches
each engine suite through the shared validation guard and retains individual
receipts. `-LockWaitSeconds 1800` can accommodate another task's long benchmark;
the guard never interrupts an existing workload. Review scripts and captures
are under `scripts/arcade_air_report.py` and `tests/arcade_air_playtest.gd`.
The matched model-26 capture is frozen; the harness rejects `--baseline` on
model 27. Use `--output=res://artifacts/<new-folder>` for another capture.

The delivered comparison covers both flip directions, repeated flips, a
backward-facing flip, combined spin/flip, release, reversal, ordinary tilt
and landings. A separate final-source `turn` capture covers ordinary steering,
release and countersteering. Both use chase and side views. Detailed receipts
and source identities are in `artifacts/arcade_air_v27/verification.json`;
the accompanying `verification.md` separates test results from visual review.

The initial September 10 run with the original 8 rad/s flips passed 14 of 16
suites, including all 5,117
focused air checks, 56 physics checks, 170 runtime checks and 213 tuck/contact
checks. Both flip directions/facings then took 0.85 seconds from rest, stopped
in 0.10 seconds and reached opposite full speed within 0.20 seconds. Rotation
and neutral controls produced identical positions and velocities at matched tuck.

Two animation suites retain five posture failures: fitted-joint continuity
during grounded turning/toggle transitions, plus procedural neck gaze, tuck
hand spacing and impact back flexion. All five reproduce with the previous
air rates. Airborne pose continuity, flip/tilt source selection, rigid boot
attachment, pole grips and body segment lengths pass. These remaining posture
failures have not been hidden or treated as a full animation acceptance.

The first player-feedback retune halved flip speed to 4 rad/s. Its 5,121
focused checks pass, including a 1.6-second first flip, 0.05-second stop, less
than 6 degrees of release drift, and continued rotation that cannot fit another
full flip into the next second. Physics, runtime, steep-upgrade and landing
absorption suites also pass. Receipts and the repeated-input production capture
are under `artifacts/arcade_air_v27/slower_flips`; the earlier captures remain
the record of the rejected faster tuning. Matched production input then produced
357 degrees of pitch instead of 710 degrees in the repeated-flip capture, with
the same starting position and v14 terrain hashes. Inspected side/chase samples
show the slower rotation and connected equipment through inversion and release.
This sampled rendered review is separate from controller-feel acceptance, which
remains with the player.

The September 11 reduction of all manual aerial rates passed 5,845 focused air
checks plus physics, runtime, steep-upgrade and landing-absorption suites.
Both flip directions/facings measured 2.65 seconds per first turn and 0.05
seconds to stop, with 2.86 degrees of release drift. Full ordinary yaw reached
1.56 rad/s and spins reached 5.4 rad/s. Matched flight trajectories remain
identical. Receipts are under `artifacts/arcade_air_v27/response_60pct`.
This parameter-only follow-up has automated evidence; the earlier rendered
captures show prior tuning, and the new controller-feel acceptance remains open.

The subsequent direct-stick update removes the L1 requirement and restores the
flip target to about 1.7 seconds while retaining the other reduced air rates.
Controller input (48), focused air (5,845), physics (56), runtime (170), rider
lifecycle (51), steep upgrade (63) and landing absorption (155) checks all pass.
Both directions/facings measure 1.708 seconds per first flip and 0.083 seconds
to stop, with 7.735 degrees of release drift. Direct-stick coverage includes
held takeoff input, centered rearming, analog strength, direction, landing reset
and interruption by pause, restart, focus loss and controller disconnect.
Receipts are under `artifacts/arcade_air_v27/direct_stick_17`. This update has
automated evidence; a new rendered/controller acceptance has not been claimed.
