# Physics-driven skier, model v9

Normal skiing now has two independently evaluated ski supports coupled to an
articulated balance controller. The simulation emits the final pelvis, spine,
head, leg and arm joints. Rendering interpolates the completed 120 Hz states;
it cannot advance hands, steer the rider or create snow contact.

## Tighter high-speed turns — model v9

The target bank limit now blends from 0.85 rad (48.7°) at 30 km/h to
0.98 rad (56.1°) at 60 km/h. A committed fast turn can build more lateral
support through the existing body lean and ski contacts. The pressure footprint,
balance response, torque cap, edge/cuff rate, slip protection and airborne
behavior retain their previous settings. Small steering inputs still request
only the lean their force demand needs. The limit applies to the target;
terrain and body angular momentum can temporarily carry actual roll beyond it.

On the 25° test plane, two seconds of full steering from 120/160/200 km/h
produces turn radii of 80/112/143 m, versus 103/143/182 m with the old bank
limit: approximately 21–22% tighter. After four seconds, travel has turned
60.1°/52.6°/47.8°, versus 47.9°/42.1°/38.3°. These are upright entry fixtures
with freely evolving speed, not constant-speed radius measurements. Harder
turns still spend momentum: four-second exit speeds are 66.8/78.9/87.9 km/h,
versus 71.5/82.9/91.6 km/h previously. Input never directly redirects velocity.

`tests/high_speed_turns_suite.gd` compares the old and new bank limits in both
directions, upright and initially tucked, and checks release/reversal after
two seconds of committed steering. Existing handling, gentle correction,
terrain, energy, crash and cuff tests remain in force. Native captures from
`tests/high_speed_turns_playtest.gd` inspect both directions from 120/160/200 km/h
on actual laboratory snow. Test runs remain unranked. Evidence and logs are in
`artifacts/high_speed_turns/`; this is gameplay calibration, not empirical
biomechanics or a guarantee of recovery from every terrain/obstacle encounter.

Model v9 uses `laboratory-v3-physics-v9-default`, separating earlier personal
bests and ghosts. Replay format remains v2. Rendering performance was not
remeasured; the solver remains independent at 120 Hz.

## High-speed balance and boot support — model v8

A 4% steering input held for two seconds and then released reproduced delayed
body-balance crashes on laboratory snow: at 7.917 s from 120 km/h and 4.925 s
from 200 km/h. Slip at the latter crash was only 0.35°. The controller counted
cross-slope gravity twice in its desired ski reaction and could demand excessive
bank as support disappeared over a crest.

The shared terrain frame now uses the geometric contact normal at the rider,
independent of pressure transfer between boots. Each ski still evaluates its own
normal, load, edging, grip and release. Balance uses the reaction that changed
velocity in the completed tick, including landing support, rather than pairing
that impulse with the next contact's predicted load. Desired lean excludes the
duplicate gravity term; anticipation is support-limited and target bank retracts
as normal load falls below static support. The existing bounded pressure torque
still moves the body. No orientation clamp, trajectory attractor or airborne
steering force was added.

The landing alignment penalty cannot exceed the normal impact speed. A light
brush against snow therefore cannot repeatedly receive a hard edge-catch penalty
based on the rider's full travel speed. Hard landings, broadside slides and
obstacle impacts still crash. Ski velocity now includes the complete tick's boot
displacement, even though contact positions are updated twice within that tick.

Crash boot cuffs use hinges with a nominal 0–32° forward-flexion envelope, keeping
the ski and boot rigidly attached. The ski collision footprint uses equipment
tuning. Angular handoff velocities are seeded about the ragdoll mass centre so
banking cannot inject additional total linear momentum. The fifteen-body Jolt
solver remains an approximation: hard impacts briefly exceed angular limits.
The 150/200 km/h fixtures measure peak cuff flexion of about 59/62°, with 11/10
out-of-envelope foot samples among 720; these are transient solver errors, not
the intended cuff range. Maximum joint separation error is about 32/46 mm.

`tests/high_speed_balance_suite.gd` covers 108 twelve-second fixtures at
120/160/200 km/h, in both directions, on inclined planes, cross-slopes and actual
laboratory terrain. It covers small held inputs, release, analogue reversals and
150 ms keyboard taps, plus pressure/frame independence, boot velocity and a
glancing landing. Obstacle collision is excluded only in these terrain-isolation
fixtures; the ordinary collision tests and rendered playtest retain it. All 108
handling fixtures finish without a crash. This does not guarantee recovery from
every sustained traverse or arbitrary terrain/impact.

Evidence is in `artifacts/high_speed_balance/`. Native Low-quality captures from
`tests/high_speed_balance_playtest.gd` inspect the two reproduced tiny-turn routes,
reversals, rigid bindings and crash motion. Test and speed-lab runs are unranked.
Model v8 uses `laboratory-v3-physics-v8-default`; older PBs and ghosts are not
compared. Replay format remains v2.

All 654 checks pass across 12 suite runs (including both crash speeds);
`validation.json` records the suite outcomes and source hashes. The native
playtest completes 22 seconds of handling and 3 seconds of crash motion. The
separate full-descent FPS check could not finish while the Mac was locked and
was stopped; no new hardware frame-rate result is claimed. The headless standard
descent finishes in 57.506 s with no crash or airtime and a 142.70 km/h peak.

## More forgiving handling — model v7

The balance controller now uses 1,500 N m/rad stiffness, 700 N m s/rad damping,
a 600 N m torque limit and a 0.85 rad (48.7°) maximum target bank. The original
ski spacing, bone lengths and cuff limits are retained. A 0.12 m support reserve
allows the rider to change lean. Reversals first bring the mass over the feet
before building the opposite bank; this takes finite time rather than snapping
body orientation.

Ski yaw retains more authority at speed (reduction coefficient 0.032 instead of
0.045), but eases further rotation into 8–18° of heading slip. This protection
blends in between 3 and 12 m/s; slow pivots remain available. Input still controls
equipment and never directly rotates velocity. The full intent reaches the
body controller even while ski yaw waits for a weight transfer.

Edge grip and sliding/braking resistance now share the lateral support budget.
Previously, resistance could add lateral force after edging had already used
the available body support. Resistance is applied first, using up to half of
that budget; edging gets the remainder. Both impulses are passive and capped
before they can reverse velocity. Sustained skidding still costs speed.

Slip recovery room increases from 2.5 to 5 m and recovery from 0.30 to 0.65/s.
Brief errors are more forgiving. Large unrecovered slides, body tips, hard
landings, trees and rocks still cause crashes. This remains a reduced support
model and gameplay calibration, not empirical ski biomechanics.

Physics model v7 creates `laboratory-v3-physics-v7-default` and separates old PBs
and ghosts. Replay format remains v2. `tests/handling_suite.gd` exercises held
turns, release, reversals, cross-slopes and real mountain samples; native captures
come from `tests/handling_playtest.gd`. Evidence is in `artifacts/handling/`.
The model-v6 validation below is historical.

## Contact and balance

`core/ski_contact.gd` evaluates each ski at its own position. Each has a normal,
heading/edge response, support/release flag, normal load, slip, grip, snow depth,
penetration, drag and landing speed. Reachable unequal heights compress the legs
differently. A support beyond leg reach contributes no force. Snow cannot pull
on an unloaded ski. The two contacts use the existing authoritative terrain and
its curvature-normal contract; they do not add a racing-line force.

`core/rider_body.gd` uses fifteen segment masses summing to the configured 80 kg
rider. Their posed centres determine COM and roll/pitch inertia. The controller
requests roll/pitch torque, then converts that request into a centre of pressure
(COP) within the supporting ski footprint. The realised reaction torque drives
body angular velocity; pressure transfers load between feet. Available edge and
braking forces are limited by the rider's current balance, so an upright rider
cannot instantly sustain the force of a deeply banked turn. Sliding grip and
friction remain passive.

With lateral coordinate x, forward coordinate z and normal reaction Fy:

```
roll torque  = (COP.x − COM.x) × Fy + COM.y × Fx
pitch torque = (COM.z − COP.z) × Fy − COM.y × Fz
```

Air drag acts through the body, not through the ski footprint. In flight, changing
tuck/limb inertia conserves the model's roll/pitch angular momentum; there is no
ground-reaction torque. A first landing on only one ski transfers an asymmetric
angular impulse. The existing hard-landing and excessive-slip checks remain;
unrecoverable body angles also trigger a crash.

Hip counterbalance, leg compression and shared-pelvis reach correction keep the
joint targets connected. Knees and elbows use two-bone IK with source-rig segment
lengths. Hand springs run at 120 Hz and react to turn, tuck, acceleration,
compression and support loss. The straight-back tuck is retained.

## Ski attachment and render timing

The two completed body snapshots retain their root translation and support
rotation. `SkierVisual.pose(sim, fraction)` uses one explicit fraction for that
frame, the joint targets and both world-space ski contacts. Its default is the
completed tick for paused sessions, tools and crash handoff. The main loop uses
the same resulting root for the camera and effects.

Each rendered ankle is derived from its rigid boot/binding transform. Two-bone
IK closes the legs against those ankles while preserving limb lengths and one
shared pelvis. This sub-tick correction does not feed back into balance, load
transfer or contact forces. Resume discards old pose/contact interpolation
history without advancing physics; restart primes the complete new stance.

The earlier independent clock reads could leave a stopped body at the latest
position while the skis cycled through the previous tick. A native 180 km/h
launch reproduced a 0.348 m ski jump and 0.348 m ankle gap during pause; moving
attachment error reached 1.88 mm. The corrected native run had no paused ski
movement and a maximum measured attachment error of 0.37 mm, including the
skeleton's final render update. Sub-millimetre floating-point error remains at
the laboratory's world coordinates. The old manual motion capture also mixed
current body position with a live engine interpolation fraction; it now poses
the completed tick explicitly.

`tests/ski_attachment_suite.gd` covers 200 km/h initial speeds on flat, inclined,
cross-sloped and laboratory terrain at five interpolation fractions, unequal
supports, hopping, paused rendering and restart. It checks actual foot bones,
boot orientation, unchanged physics, segment lengths and pelvis attachment.
`tests/rider_lifecycle_suite.gd` additionally checks resume before the next tick.
`tests/ski_attachment_playtest.gd` measures the rendered skeleton during a native
high-speed descent, pause and resume. Evidence is in `artifacts/ski_attachment/`.
Movie-writer captures are for visual inspection, not hardware FPS measurement.
That attachment fix changed presentation/history only and retained model v5.
The later turning correction below changes handling and uses model v6.

After this fix, all 212 checks across physics, runtime, articulation, attachment,
crash lifecycle, ragdoll and native graphics suites pass. The complete Low-quality
snowfall benchmark on Apple M4 at 1440×900 measured 8.33 ms mean (~120 FPS),
8.65 ms p95, 10.28 ms p99 and 85.3 FPS slowest-1% mean. It finished in 57.495 s
without a crash or airtime, with screenshot capture disabled. Report:
`artifacts/weather_benchmark_ski_attachment_low.json`.

## Turning anatomy — model v6

The previous rig permitted the skis to edge to 62° while the rider remained
nearly upright. Its knee target used world-forward and its shin rotation omitted
axial alignment, concentrating the difference at the boot cuff. A hard-steering
reproduction measured almost 86° of sideways cuff-to-shin bend.

The ski edge target now follows the rider's physical bank with a ±0.10 rad
angulation allowance and a maximum rate of 3 rad/s. Steering heading still
responds on the input tick; this limit controls boot roll, not yaw. Each ski
retains its separate response, normal, support and load. The HUD distinguishes
requested edge from actual right/left edge angles. The angulation allowance and angular-rate bound are authored gameplay parameters.

Hip displacement scales with stance height. Knees select the two-bone solution
closest to each boot's forward-flexion plane, and shin/thigh skin frames carry
the boot hinge axis. Both the physical pose and render interpolation use this
constraint while retaining fixed segment lengths and the shared pelvis. A
bounded shared-pelvis projection also enforces the cuff envelope (±10° sideways,
0–32° forward flexion), including the extreme lean before a crash. It stops
early when both legs already satisfy their constraints, with a maximum of
sixteen iterations for difficult poses. The torso follows every pelvis correction.
The knee preference includes more forward flexion to avoid outward splay when
the hips lower. Upright, half-tuck and full-tuck regression poses keep the knees
within 1 cm of their boot centerlines; the rigid bindings and stance width stay
fixed.

Roll/pitch and angular velocity are transported into each new support frame.
Changing terrain normal therefore preserves the existing world lean instead of
instantly rotating the body mass and causing a false tip. The model still uses
a reduced two-axis balance controller; it is not a general rigid-body controller
for normal skiing. Crashes continue to use the separate Jolt skeleton.

These changes affect COM, contact grip and timing, so model-v5 times and ghosts
are not compared with model v6. Replay format remains v2. Unranked test/lab runs
cannot write personal bests. The original Meshy assets/materials are unchanged.

`tests/turn_anatomy_suite.gd` checks full steering and reversals from 0–200 km/h,
hip follow-through, boot/shin side bend, forward flexion, skin twist, attachment,
edge angular rate, cross-slope balance and support-frame transport. Native
`tests/turn_anatomy_playtest.gd` renders both directions and reversals from behind
at close range. Evidence, including the original reproduction, is saved under
`artifacts/turn_anatomy/`.

## Crash physics

`presentation/skier_ragdoll.gd` transfers the final solved transforms and velocity
to fifteen `PhysicalBone3D` bodies. Joint constraints are constructed after all
bodies are positioned at handoff. Knees and elbows use hinges with a 0–140° bend
envelope relative to their initial flexion; other joints use limited cones/twist.
The bodies total 80 kg and use continuous collision detection. Jolt's 32 velocity
and 12 position iterations reduce impact stretching; they do not change the ski
solver's 120 Hz step.

Normal control stops on crash. The camera follows the physical hips, first-person
switches to a visible crash view, and restart restores the previous camera mode.
Focus loss freezes the crash and focus regain resumes it. A crash settles/freezes
after at most 15 seconds. Restart removes temporary ski collision shapes, stops
physical simulation, clears body/hand state and restores ordinary posing.

`world/crash_collision.gd` prepares nearby exact rendered terrain triangle shapes
and the existing cylinder obstacle envelopes. These collide only with crash
bodies. Chunks outside the bounded neighbourhood are released. Equipment follows
the physical bodies directly: reading the ordinary skeleton pose outside its
modifier callback would instead read the restored pre-ragdoll input pose.

## Materials and grips

`scripts/art/skier_details.py` assigns actual polygons to clothing, helmet,
curved amber lens and skin materials. The open generated hands are replaced by
closed glove geometry with four curled fingers, a crossing thumb and overlapping
wrist cuffs. Handles share the gloves' fixed grip axes.

Visual Settings → Skier Materials controls tint, glossy/matte finish and metallic
reflection independently for clothing, helmet and lens. Settings persist in
`user://skier_appearance.cfg`; they do not affect competitive eligibility.
The reset button restores the authored finishes. Shader registrations are reused
through quality switches. The source `.blend`, semantic surfaces and 24-bone skin
round-trip through GLB. The complete rider/equipment uses 42,063 base triangles.
No new Meshy operation was needed: the earlier total remains 40 of the authorised
1,000 credits.

## Replay identity

Benchmark identity is `laboratory-v3-physics-v9-default`. Replay format v2 records
fifteen joint positions plus each ski's position, normal, heading, edge and contact
flag at 30 Hz, alongside 120 Hz inputs. Ghosts interpolate recorded articulation;
they do not reconstruct the old decorative edge/tuck pose. Malformed and older
replays are rejected. Model, engine and default tuning checksums remain pinned.
The bounded ten-minute record allowance is 32 MiB of uncompressed JSON, saved
using the existing atomic compressed format. Test directories remain isolated
from personal bests.

## Validation — model v6

All **359 checks across ten suites pass**: physics 54, runtime 72, turning
anatomy 32, ski attachment 20, articulation/materials 19, race authoring 51,
competition 64, ragdoll 9, crash lifecycle 13, and native graphics 25.
`artifacts/turn_anatomy/validation.json` indexes results and source hashes.
The default headless descent finishes in 57.4877 s at 142.578 km/h peak, with
no crash or airtime; identical tick input is independent of render schedules.

The original hard-steering cuff bend of almost 86° is reduced to about 10°
maximum in the turning fixtures, including mountain reversals immediately before
crash handoff. Maximum measured boot attachment error is 0.4972 mm; maximum
shin skin-axis error is 0.000988°. Upright, half-tuck and full-tuck knees are
within 8.64 mm of their boot centerlines, compared with up to 18.99 mm outward
before the final knee adjustment. The separate 150 km/h ragdoll check passes;
its maximum transient joint error is 49.4 mm. These are reduced-model geometry
checks, not a claim of anatomically exact human biomechanics.

Native rear/side turn and reversal captures were inspected at 1280×900 on
Metal, including both loss-of-balance handoffs. The 60 FPS movie is
`artifacts/turn_anatomy/turns_v6.mp4`; its capture/encoding overhead is excluded
from the independent full-descent performance reports. Deliberate sustained
full-input reversals can still exceed physical balance and crash.

The lag investigation also found an orphaned MCP Node process consuming one
CPU core continuously. A sample showed an immediate-callback/uncaught-exception
loop. That process and an old orphaned test run were stopped; the toolkit and
project configuration were preserved. Evidence is `mcp_cpu_sample.txt` in the
same artifact directory. This is a measured source of background contention,
not proof that it caused every reported pause or steering delay.

The final full-descent measurements use Apple M4 / macOS / Godot 4.7.2 /
Forward+ Metal, **1440×900 actual pixels**, snowfall with High weather quality
(1,700 particles), and no screenshot capture. The first 120 frames are excluded.

| Graphics | Average FPS | Mean ms | p95 / p99 ms | Slowest-1% mean FPS |
|---|---:|---:|---:|---:|
| Low | 115.1 | 8.691 | 12.419 / 13.472 | 65.2 |
| Balanced | 91.6 | 10.913 | 14.918 / 15.681 | 57.6 |

Both runs finish in 57.4876 s at 142.578 km/h peak with no crash or airtime.
Low meets the approximately 60 FPS target in this configuration, including its
slowest-1% average. Balanced has occasional slower frames and is not held to the
Low target. GPU timing is unavailable; these sequential desktop measurements
are not a controlled attribution of frame-time changes to one code edit.
Raw reports are `artifacts/weather_benchmark_turn_anatomy_low.json` and
`artifacts/weather_benchmark_turn_anatomy_balanced.json`.

## Original model-v5 validation

Historical evidence lives in `artifacts/advanced_rider/`:

- Physics: 54 checks; clean benchmark 57.495 s, peak 142.59 km/h, no crash/airtime.
  Identical tick input remains identical under 30/60/120/144/240 render schedules.
- Runtime: 72 checks. Articulation/materials: 19 checks, including one-foot support,
  independent snow depth, preserved segment lengths, COM, bounded COP, airborne
  angular momentum, immutable render input and locked pole grips.
- Graphics: 25 native-renderer checks. Races: 51 checks. Competition: 64 checks,
  including recorded poses, malformed replay rejection and untouched user records.
- Crash lifecycle: ten checks for mode handoff, camera restoration, focus pause,
  repeat restarts, material reuse and the crash time bound.
- Crash: nine checks at 200 km/h. All bodies remain finite and ground collision
  holds; maximum transient joint-length error was 0.054 m and lowest body centre
  was −0.017 m relative to the flat test plane. Capsules, not their centres, are
  the collision surfaces. The same suite also exercises focus pause and restart.
- Full rendered snowfall descent: Apple M4 (Apple9), macOS, Godot 4.7.2, Metal
  Forward+, Low graphics, High weather, 1440×900 actual pixels. Mean 8.33 ms
  (~120 FPS), p95 8.54 ms, p99 8.71 ms, slowest-1% mean 93.2 FPS. 6,763 measured
  frames, first 120 excluded, no screenshot overhead. GPU timing unavailable.
  Report: `artifacts/weather_benchmark_advanced_rider_low_snowfall.json`.

Run `tests/advanced_rider_playtest.gd` natively for actual simulated turns/tuck/hop,
close grip and material views, controls and the high-speed terrain crash sequence.
`tests/skier_asset_playtest.gd` additionally provides controlled posture views;
those are geometry inspections, not physical descents. Headless checks do not
establish visual feel or hardware performance.

## Deliberate limits

This is a reduced articulated skiing model, not a muscle-level human simulation.
Root translation and roll/pitch balance are integrated; limb targets come from
constrained IK. It is not a 24-rigid-body controller during normal skiing. The
skis have independent contact/force states but fixed lateral stance anchors,
with no flexible ski beam or distributed tip-to-tail pressure integration.
The existing 4 m terrain grid/stencil limits contact detail. Compression is a
controlled leg-height spring, not an energy-returning pumping system.

Crash bodies are approximate capsules with self-collision excluded for stable
connected joints. Brief joint error, mesh clipping and skinning artifacts are
possible at severe impacts. The boots and skis remain bound; poles stay in the
hands and do not have their own collision solver. There is no binding release,
cloth simulation, finger articulation or injury simulation. Crash Jolt trajectories
are not claimed to be bitwise deterministic across platforms and are not ranked
replays. The measured Low result applies to the tested M4, resolution and course.

Godot implementation references: [physical bones](https://docs.godotengine.org/en/stable/classes/class_physicalbone3d.html),
[physical bone simulator](https://docs.godotengine.org/en/stable/classes/class_physicalbonesimulator3d.html),
and [engine joint setup](https://github.com/godotengine/godot/blob/4.7-stable/scene/3d/physics/physical_bone_3d.cpp).


## Airtime and landings — model v10

Flight retains the takeoff support frame. Equipment yaw is available, while
terrain normals below the skier cannot rotate airborne skis. Gravity and drag
remain the only airborne linear forces. The leg-height spring draws knees up
at release (0.86 m upright to 0.78 m tucked); angular momentum still responds to
the articulated inertia, with no upright snap or automatic trajectory steering.

Before a supported step, a ballistic next-height probe checks for snow falling
away, with 2.5 cm numerical tolerance and the existing differential leg offset.
Negative required support now always releases contact. Smooth, constant-pitch
snow still supports normal downhill skiing; crests and cliffs produce airtime.

Swept impact uses the actual triangle normal. After a safe landing, the remaining
tick advances along the surface or releases again if the snow falls away. This
fixes the old repeated near-zero-time impact that could pin the skier at a lip.
Gravity/drag integrate once per tick. A completed impact retains its support footprint through the existing leg
reach, even if the skis immediately leave the surface again. The body controller
applies landing torque through that one- or two-ski support; the separate one-ski angular kick was
removed because it duplicated that reaction. Hard normal impacts and bad landing
alignment still consume balance or crash; Space supplies the existing 3.2 m/s
normal impulse and cannot supply another impulse in midair.

Run `tests/jump_suite.gd` for abrupt ledges, terrain-independent flight orientation,
ballistic motion and feature landings across six seeds. `tests/jump_playtest.gd`
provides native Space-hop, cliff flight, landing, terrain and survey captures.
Evidence is under `artifacts/jump_upgrade/`. Model v10 isolates benchmark/PB/ghost
compatibility from previous physics. This remains a reduced articulated model
with fixed stance anchors and 4 m heightfield support, without overhangs or a
full aerial trick/control system.
