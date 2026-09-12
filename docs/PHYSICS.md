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
Gravity, bounded pole thrust, drag, passive grip and braking determine speed.
Turning requests act through yaw, bank, pressure and normal reaction, never a
desired travel path.

## Controls

[InputRouter](../scripts/core/input_router.gd) is the binding/ownership source;
[RiderInput](../scripts/core/rider_input.gd) is the equipment-neutral intent.

| Intent | Keyboard | Controller |
|---|---|---|
| Steer | A/D or left/right | Left-stick X |
| Hold forward: push / tuck; brake | W/up; S/down | Left stick forward; L2 or LT |
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

Model 30 releases the bank-following cuff restriction for steering at or below
10%, smoothly restoring it by 25%. The former `-bank +/- .10` edge-goal window
could keep skis deeply edged after a reversal even when the requested edge and
path curvature had faded. Rigid-cuff leg fitting then required a sideways pelvis.
`SkiSimulation._update_contacts` now lets weak/released intent seek its requested
edge through the existing loaded motor response and 3 rad/s rate limit. Strong
turns retain the bank coupling. Balance torque, anatomy and presentation ownership
remain intact; this is an equipment-control change, not an assigned body pose.
Release paths intentionally change, so the existing identity contract rejects
model 29 recordings; replay format remains 7. Aggregate bank can still
transiently overshoot while the edges unwind; this does not retune the balance
integrator. Final connected stance and support recovery are checked separately.

Forward repeats pole pushes while slow on supported snow, then blends into
aerodynamic tuck over 80–100% of the applicable propulsion limit. Small corrections
have a 20% allowance and 150 ms grace before sustained steering opens the stance;
centering steering with forward held returns to tuck. Tuck does not remove
manual steering authority. Keep changeable coefficients in the tuning resource,
not a second documentation table.

## Pole propulsion

`core/pole_propulsion.gd` advances once per 120 Hz skiing tick after authoritative
support/jump decisions. It adds bounded thrust along the intended ski heading
projected onto support, including traverses. It publishes phase, intensity,
loaded power, actual acceleration, signed grade and the current speed limit.
Animation and cosmetic pole-tip contacts only observe those completed values.

The default grade/upper propulsion-limit knots are 0°/40, 10°/30, 20°/17,
28°/12, 34°/8 and 42°/0 km/h, with smooth interpolation and assistance fading
from 34° to 42°. These limit added propulsion; they are not measured steady
climb speeds. Full tangential speed gates thrust. Only positive added impulse
is bounded: carried momentum is never clamped and downhill gravity remains free.
The default peak thrust ceiling is 22 m/s², with taper in the last 14% of the
applicable limit. Force/cadence/curve settings belong to `SkiTuning` and
`config/ski_default.tres`, which contributes to record identity.

Both skis must carry snow, agree with the support normal and avoid sharp-lip
suppression. Release, brake, jump preparation/release, crash, unsupported travel,
rock, switch, excessive bank/steer, rapid rollback or sideways motion suppress
thrust. Small steering remains available. Default rollback and sideways bounds
are .8 and 2 m/s; their exact eligibility tests live in the actuator.

The loaded authored phase is .06–.76. The solver shortens physical contact as
speed increases and publishes the retimed phase; render clocks never advance it.
Reset, contact priming and input cancellation clear stroke state. Pause holds it;
visual release may ease after force has stopped. No additional physical pole
collision, normal force, adhesion or lift is introduced. `jump_held` now affects
force and is replay input nine; camera look remains outside recorded rider input.
[Animation](ANIMATION.md#pole-pushing) owns the visible stroke and tip fitting;
[Validation](VALIDATION.md#pole-propulsion-and-animation-producers) owns its checks.

## Snow contact and small banks

Physical loose depth comes from [World](WORLD.md#physical-snow). Contact combines
depth, penetration, load and slip into embedded-ski resistance, especially in
turns/weight transfer. Skis do not excavate a persistent physical rut. Cosmetic
tracks, spray and powder read completed per-ski response.

`snow_crush_contact.gd` supplies bounded local yielding of small banks, limited
by available loose snow and a 30 cm crush cap. Its effective pressure/depression
is separate from the 28 cm leg-suspension reach. Clearance, visual placement and
crush sampling must agree; no independent low-resolution contact surface.

`snow_contact_assist.gd` retains the grounded-snow response introduced in model 28.
Rebound is softened and eligible smooth snowy support can dissipate separating normal velocity
within leg reach. It cannot add kinetic energy, move position, assign heading
or restore speed. The correction is not compressive load and creates no grip
budget; ordinary suspension/gravity/friction still integrate afterward.

Model 31 identifies takeoffs from the signed change between 4 m height chords
along the skier's actual travel direction. Only a convex grade break above
10 degrees suppresses retention. Sideways triangle-normal changes and concave
landing pockets no longer disable absorption and trigger repeated small hops.
The chords still detect real ledges with parallel normals; neither absolute
steepness nor a lateral ridge alone is a lip. The same 4 m heights, existing
reach, 3 m/s dissipation cap and snow/material gates remain authoritative.
A sharp break suppresses retention until departure/landing or 150 ms of loaded,
non-separating smooth support. Pending/buffered jumps bypass it before impulse
consumption. Airborne, out-of-reach and non-snow contacts do not retain support.
Restart/teleport/contact priming, departure and leaving snow clear histories.
The tick owner advances the helper once; probes/rendering cannot advance it.
Diagnostics distinguish correction m/s, dissipated J/kg, eligible skis and
release reason. Test rounded bumps separately from sharp drops and actual jumps.

`tests/terrain_settle_suite.gd` checks actual cross-slope/concave/convex 4 m
fixtures and two bounded 15-second current-mountain sections. The rough case
reproduces repeated unintended flight in the earlier detector. The existing
snow-grounding contracts retain jump/buffer, cliff, rock, mixed-foot, energy,
reach and reset checks. `scripts/capture_small_landing.ps1 -Terrain
-OutputDirectory artifacts/terrain-review -View side` captures the final seven
seconds after an eight-second ordinary-input lead-in, using production skier/
camera code on the real heightfield patch. It preserves real obstacle responses
but omits scenery rendering; this is contact-motion evidence, not scene FPS.
`-View chase` selects the gameplay camera. A frozen detector under `artifacts`
can be supplied as `-ReferenceAssist` for a labelled causal comparison. Physics
model 31 rejects model 30 recordings through the existing identity check; replay
format remains 7. No old-record migration or speed restoration is introduced.

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
Local recovery uses ordinary reset/contact priming without a solver tick, then
clears translational and angular settling velocities. Placement and retained
attempt timing belong to [Racing](RACING.md#crash-location-recovery).

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
