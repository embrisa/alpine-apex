# High-speed skid steering and pelvis presentation — physics v22

The user reported seconds of resistance to turning the skis during high-speed
skids. Clean-carve reversal tests measured only the first trajectory response
and did not reproduce that loss of equipment rotation.

## Cause and correction

The old yaw limiter reached zero at 18 degrees of equipment/travel mismatch.
With continued input it could hold the skis motionless until grip aligned the
travel direction. Initial 60-degree skids produced 2.14 seconds of zero yaw at
120 km/h and 2.55 seconds at 200 km/h. Some near-broadside cases remained locked
through the entire eight-second probe while retaining snow support.

Ordinary carving regulation remains unchanged. Extra manual authority ramps in
between 18 and 30 degrees of skid, or after a command has remained below 5%
authority for 120–250 ms. Established skids retain 65% manual yaw by default.
The weight-transfer and skid restrictions stop multiplying each other during
that release. Actual grip, contact loads and body pressure still govern travel;
there is no velocity assignment, extra snow force or airborne steering force.

`SkiTuning.skid_steering_authority` is developer calibration. Simulation telemetry
exposes requested/applied yaw, separate limiter factors and stall age. F3 displays
yaw in degrees/second, limiter percentages and physical COM coordinates. Release,
restart and flight clear the stall timer. Physics identity is v22; replay remains
v4 and incompatible records remain separated.

## Pelvis presentation

The subsequent [compact posture correction](../presentation/COMPACT_POSTURE.md) adds a small
deep-tuck pelvis offset and gathers skiing/jump arms through local rotations.

Physical hips already sit behind the boots in neutral skiing; source animation
could replace that with a pelvis ahead of them. Grounded presentation retains
65% lateral following and uses 95% following for crouch height and fore/aft
placement. It retains deeper source compression and adds up to 3 cm of lowering
and 5 cm of rearward expression in tuck/carve. The physical lowering now leads
the visible pelvis instead of disappearing underneath absolute source height.
Takeoff and flight fade this anchoring out. Final fitting and rigid bindings
remain authoritative for the visible rig; physical mass properties are unchanged.

The knee follows a bounded sine of the source/cuff pole difference, avoiding a
signed-angle branch at opposite directions. Its source influence also fades when
the source knee approaches the hip/ankle axis, where a pole direction is undefined.
This prevents millimetres of source movement from flipping the fitted knee.

## Validation

Run `tests/skid_response_suite.gd`, physics/runtime, carving, high-speed balance,
contact/landing/rock, deep-tuck/anatomy, pelvis-balance and attachment/lifecycle checks. The skid
probe records first and sustained authority and actual ski-motor rotation,
separately from trajectory response. Its eight-second matrix covers both input
directions, heading-wrap boundaries, reversals, tuck and brake release.

Independent headless tests may run concurrently with separate result paths.
Tests sharing result paths run sequentially; stagger startup to avoid the MCP
toolkit's shared registry-file race. Run rendering/timing in isolation.

Native inspection: `tests/steep_motion_gameplay.gd '--' --skid-review` or
`--pelvis-review`.
Current evidence and acceptance limits live in
`artifacts/steering_response_v22/ACCEPTANCE.md`. Numerical and rendered results
are separate from the user's final handling and animation acceptance.
