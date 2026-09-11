# Jumping, flight and switch skiing

Hold the jump action to prepare; release to request one hop. Holding longer does
not charge a larger impulse. The supported ledge tick consumes a release before
support loss, and a 75 ms buffer accepts a release shortly before landing.
Pause, focus loss, menu transitions, crash and restart cancel/rearm input safely.

## Controls

- Space or R2/RT: hold preparation, release to hop. Cross/A confirms menus and drops from the summit; it does not request a hop.
- W/S or up/down, or left stick forward/back: limited air pitch after centering once after takeoff.
- Q/E: airborne spin; I/K: flip; Shift: grab.
- Gamepad left shoulder plus left stick: spin/flip, suppressing stick tuck; west button: grab. Keyboard W/up remains available while the modifier is held.

Manual angular commands rotate the physical flight frame at bounded speed and
acceleration without adding linear propulsion. A commanded trick suppresses
automatic alignment for that flight. New held controls must be released after
lifecycle transitions before rearming. Camera look remains independent.

## Facing, prediction and assistance

Forward and backward skiing share travel-relative controls and handling. The
facing convention keeps rigid bindings and physical lean in matching frames;
visual facing cannot change COM, inertia, grip or reserve damage.

`core/landing_assist.gd` supplies bounded ballistic footprint prediction over the
authoritative terrain. Invalid/out-of-bounds predictions are discarded. Motion
shares its predicted timing and normal for cosmetic landing readiness even when
physical assistance is disabled.

Ground and air assistance default off. Optional help rotates the physical frame
without assigning linear velocity or creating support. Target acquisition,
manual override and release must hand over gradually; explicit controls retain
priority. Do not restore the old instantaneous/fast landing-alignment behavior
from superseded model reports. See [ski physics](SKIER_PHYSICS.md).

`core/rider_facing_pose.gd` and the presentation layer interpolate compatible
physical frame, joint and equipment histories. The production character fits
limbs to rigid bindings through one final skeleton writer. Crash handoff uses
the completed pose and physical world angular velocity. See
[animation ownership](SKIER_ANIMATION.md) and [anatomical constraints](SKIER_ANATOMY.md).

## Landing reserve and compatibility

[Impact recovery](IMPACT_RECOVERY.md) owns automatic slope-matched absorption,
contact grouping, damage and recovery. Clean landings do not require a timed
crouch input. Avoid copying obsolete damage percentages or balance-death rules.

The solver source owns the physics model version; replay format is v5. Records
remain isolated by complete race, mountain, engine, model and tuning identity.
Test and laboratory runs do not enter personal bests.

## Validation

Use `tests/jump_suite.gd`, `tests/airborne_control_suite.gd`,
`tests/airborne_pose_suite.gd`, `tests/landing_absorption_suite.gd` and lifecycle
checks for the relevant change. Run physics/runtime suites for physical input or
session changes, then inspect native ordinary hops, natural drops, switch,
manual flight, optional assistance, clean/awkward landing and crash/restart.

Some older native harnesses intentionally pin historical terrain fixtures. Use
the [current v13 setup](ALPINE_V13.md#fast-test-setup) for full-mountain acceptance;
headless checks do not establish skiing feel or continuous motion quality.
