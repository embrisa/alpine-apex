# Physics and input

## Ownership and tuning

[SkiSimulation](../scripts/core/ski_simulation.gd) owns translation, contact,
body response and airborne rotation. [SkiContact](../scripts/core/ski_contact.gd),
[RiderBody](../scripts/core/rider_body.gd), [tuning](../scripts/core/ski_tuning.gd)
and [default values](../config/ski_default.tres) define the model. Use metres,
seconds and radians; reserve is impact capacity, not stamina. Current identity
and timing are in [Architecture](ARCHITECTURE.md).

Each ski has unilateral support, its own normal/load, yaw/edge, slip,
penetration and release state. Root translation is constrained by actual
support. Physical segments define COM/inertia; cosmetic IK does not change them.
Gravity, drag, passive grip and braking determine speed. Turning requests act
through yaw, bank, pressure and normal reaction, never a desired travel path.

## Controls

[InputRouter](../scripts/core/input_router.gd) is the binding/ownership source;
[RiderInput](../scripts/core/rider_input.gd) is the equipment-neutral intent.

| Intent | Keyboard | Controller |
|---|---|---|
| Steer | A/D or left/right | Left-stick X |
| Tuck / brake | W/up / S/down | Left stick forward / L2 or LT |
| Prepare then hop | Hold Space, release | Hold R2/RT, release |
| Limited airborne pitch | W/S or up/down after centering | Direct stick is explicit flip control, below |
| Continuous flip / spin | I/K / Q/E | Center left stick once airborne, then forward/back flips; optional L1/LB + stick also enables flips/fast spins |
| Grab | Shift | West button |
| Restart / camera | R / C | North button / right shoulder |
| Pause / telemetry | Escape / F3 | Start/Options / Back/Share |

Cross/A confirms menus and drops from summit staging. Gameplay and camera
sampling are distinct. Focus loss, menus, pause, restart and device changes
cancel pending jump/air input and require neutral where the router specifies;
held takeoff tuck must not trigger a direct-stick flip. UI text fields do not
dispatch skiing shortcuts. The complete shortcut inventory also lives in Controls.

## Carving, skidding and tuck

Carving coordinates equipment yaw, bank, pressure and grip. High-speed skid
response releases sustained equipment-yaw suppression while retaining ordinary
carving/support; visual pelvis/arm behavior is separately owned by animation.
Steering/body lean alone cannot cause a balance death.

Forward requests tuck, reducing drag without propulsion. Small corrections have
a 20% allowance and 150 ms grace before sustained steering opens the stance;
centering steering with forward held returns to tuck. Tuck does not remove
manual steering authority. Keep changeable coefficients in the tuning resource,
not a second documentation table.

## Snow contact and small banks

Physical loose depth comes from [World](WORLD.md#physical-snow). Contact combines
depth, penetration, load and slip into embedded-ski resistance, especially in
turns/weight transfer. Skis do not excavate a persistent physical rut. Cosmetic
tracks, spray and powder read completed per-ski response.

`snow_crush_contact.gd` supplies bounded local yielding of small banks, limited
by available loose snow and a 30 cm crush cap. Its effective pressure/depression
is separate from the 28 cm leg-suspension reach. Clearance, visual placement and
crush sampling must agree; no independent low-resolution contact surface.

`snow_contact_assist.gd` provides model-28 grounded retention. Rebound is softened
and eligible smooth snowy support can dissipate separating normal velocity
within leg reach. It cannot add kinetic energy, move position, assign heading
or restore speed. The correction is not compressive load and creates no grip
budget; ordinary suspension/gravity/friction still integrate afterward.

Raw normals and 4 m height chords detect a local break above 10 degrees. Chords
also catch ledges with parallel triangle normals; absolute slope is not a lip.
A sharp break suppresses retention until departure/landing or 150 ms of loaded,
non-separating smooth support. Pending/buffered jumps bypass it before impulse
consumption. Airborne, out-of-reach and non-snow contacts do not retain support.
Restart/teleport/contact priming, departure and leaving snow clear histories.
The tick owner advances the helper once; probes/rendering cannot advance it.
Diagnostics distinguish correction m/s, dissipated J/kg, eligible skis and
release reason. Test rounded bumps separately from sharp drops and actual jumps.

## Jumping and flight

Hop occurs on release with a fixed impulse; holding prepares posture, not a
larger charge. Existing ledge/buffer logic may deliver an eligible queued hop.
Prediction is read-only information for cosmetic readiness/optional assistance.
Manual input overrides assistance; assistance is off by default.

[AirRotation](../scripts/core/air_rotation.gd) integrates quaternion/angular
state without writing linear flight state. A direct-stick flip takes about
1.7 seconds; release brakes explicit rotation. Keyboard limited pitch uses
`RiderInput.air_tilt`, bounded to 50 degrees either side of its reference.
Release holds the resulting attitude; after an explicit flip stops, the stopped
attitude becomes the reference and limited pitch must center again.
Whole-equipment rotation is separate from trick-history pose selection.

Keep tuck equal in paired trajectory checks: air orientation ownership does
not remove tuck's separate drag effect. Brief supported recovery over ripples
is distinct from intentional pitch/tricks in flight. Incomplete rotations retain
their actual landing consequences. Replay stores limited tilt as its eighth
tick-input field; camera look never writes those inputs.

## Impacts, rock and crashes

Impact reserve groups rough contacts and absorbs clean slope-matched landings.
Severity uses relative normal impact, sustained roughness, equipment/body contact
and available recovery; smooth supported skiing restores reserve. Do not derive
damage from screen shake, presentation lean or a decaying impact display.
The retained recovery/absorption implementation lives in the simulation/tuning;
`presentation/impact_warning.gd` maps reserve to the screen warning independently
of optional camera-motion settings.

Rock uses the authoritative material, stable ski-normal response, abrasion and
hard-contact behavior. Spark/scrape/haptic observers read it without adding
physical colliders. Solid geology/trees and race props participate in the shared
obstacle contract. A crash hands pose/momentum to Jolt; attached rigid skis,
boots and poles and the fifteen-body collision model remain separate from the
normal solver. Repeated resting crash contacts must not retrigger onset effects.

## Controller feedback

[RiderHaptics](../scripts/presentation/rider_haptics.gd) samples its own completed-
tick contact observer independently of audio mute. Landing/obstacle onsets below
3.5 m/s normal closing speed are silent. From 3.5 to 14 m/s, normalized squared
closing speed drives motor strength and 45–180 ms duration; overlaps use maximum
strength and cannot extend a cluster beyond 180 ms. Travel speed and reserve
damage are not the intensity input. Supported-rock taps remain faint/spaced.

The Vibration setting multiplies both motors, including zero. A final crash
impact may finish, but continuous crash state/low reserve/equipment/near misses
do not generate rumble. Inactive views, focus loss, restart, device lifecycle,
shutdown and zero intensity clear feedback. Observation never mutates physics.
See [input evidence](VALIDATION.md#input-and-controller-evidence) for measured
coverage and the unresolved real-device comfort gate.
