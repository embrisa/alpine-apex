# Ski physics

`MODEL_VERSION` in `scripts/core/ski_simulation.gd` defines the active physics
identity; the current replay format is **v5**. Normal skiing uses the
custom Node-independent solver at 120 Hz. Animation and camera frames cannot
advance it, create support or steer the rider. Read [architecture](../development/ARCHITECTURE.md)
before changing simulation/contact and [online boundaries](ONLINE_COMPETITION.md)
when changing input, race identity, recordings or results.

## Steering and support

[Current carving](ARCADE_CARVING_V20.md) coordinates yaw demand, grip, bank,
pressure reserve and the supported stance. The stronger snow response blends in
above 25% steering and between 30–60 km/h. Forces remain limited by actual ski
loads and body support. Small corrections, rock grip and airborne authority keep
their existing rules. Steering never directly assigns velocity or a racing line.

[Auto tuck and contact v21](TUCK_CONTACT_V21.md) retains tuck through small
corrections and a 150 ms steering tap window, then opens it for sustained turns.
Default tuck has full steering grip and edge response. Bounded passive damping
and brief, slow recontact within leg reach reduce small-bump airtime.

[Grounded snow v28](GROUNDED_SNOW_V28.md) adds the requested bounded arcade
retention over rounded snow. It removes separating velocity while real support
is reachable, without counting the correction as compressive load or extra grip.
Snow has softer compression, stronger rebound damping and 0–30 km/h bank-crush
activation. Jumps, sharp breaks, rock and established flight retain their rules.

[Skid steering v22](SKID_RESPONSE_V22.md) retains manual ski rotation during
established skids and releases prolonged limiter stalls. Grounded presentation
follows the physical pelvis more closely without feeding animation into forces.

`core/ski_contact.gd` evaluates two independent ski supports: surface normal,
heading/edge response, load, slip, grip, snow depth, penetration and landing speed.
Spring/damper support and bounded leg reach accommodate unequal heights. An
unreachable or unloaded ski contributes no pulling force. Contact uses the shared
4 m support surface; presentation relief does not add another collider.

`core/rider_body.gd` derives physical COM and inertia from its segment model.
The controller requests roll/pitch torque through a centre of pressure inside
the supported ski footprint. Available grip and braking depend on normal load
and supported stance. Skidding and braking dissipate energy; tuck reduces drag.
Cosmetic bones never feed mass, COM, grip, damage or forces back into this model.

## Jumps, flight and impacts

[Jump controls](JUMP_CONTROL.md) own hold-to-prepare/release-to-hop, the supported
ledge tick, early landing buffer, switch controls and lifecycle cancellation.
Manual spin/flip input rotates the physical flight frame without linear propulsion.
Landing prediction is shared read-only information for presentation and optional
assistance. Explicit controls have priority; assistance must hand over gradually.

[Impact reserve](IMPACT_RECOVERY.md) groups rough contacts, absorbs well-aligned
landings and restores reserve during smooth supported riding. Empty reserve
causes an impact fall. Steering, slip or cosmetic body lean alone do not cause
balance deaths. [Rock wear](ROCK_TERRAIN.md) remains a separate source of reserve
damage and reduced traction.

## Ski attachment and render timing

The two completed body snapshots retain root translation and support rotation.
`SkierVisual.pose(sim, fraction)` uses one interpolation fraction for the body,
joint targets and both world-space ski contacts. Paused sessions and crash
handoff use the completed tick. The camera and effects use that same posed root.

Rigid boot/binding frames determine rendered ankles. One shared pelvis and
constrained leg fitting close the limbs without changing physical contacts.
Resume discards old interpolation history; restart primes a complete new stance.
The production character is the single final skeleton writer. See
[animation ownership](../presentation/SKIER_ANIMATION.md) and [anatomical fitting](../presentation/SKIER_ANATOMY.md).

`tests/ski_attachment_suite.gd`, `tests/rider_lifecycle_suite.gd` and the native
`tests/ski_attachment_playtest.gd` cover moving/paused attachment and lifecycle
behavior. Rendered inspection remains separate from headless numerical checks.

## Crashes and equipment

`presentation/skier_ragdoll.gd` transfers final solved transforms and physical
velocity to fifteen Jolt bodies. Normal ski control stops; the crash camera follows
the rider, and restart restores ordinary posing. Focus loss pauses the crash;
its lifecycle freezes after at most 15 seconds. Jolt's configured iterations
serve crash joints, not the ski solver.

Crash geometry follows the authoritative terrain and current scenery collision
contracts. [Geology](../world/GEOLOGY_V11.md) covers solid mineral proxies. Equipment
follows the physical handoff; it cannot create normal-skiing force authority.
See [skier assets](../presentation/SKIER.md) and [equipment](../presentation/EQUIPMENT.md) for editable sources.

## Identity and validation

Model changes isolate incompatible records. Replay format, engine, mountain,
race, tuning and tick rate participate in compatibility. Test/lab/autoplay runs
remain unranked; see [competitive records](COMPETITIVE_LOOP.md).

Run physics/runtime suites for simulation changes, then focused contact, carving,
jump, impact, rock and lifecycle checks for the affected behavior. Use native
inspection for visible fitting and capture-free full-mountain measurements for
performance. [Validation](../development/VALIDATION.md) records the current acceptance boundaries.
