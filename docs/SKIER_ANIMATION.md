# Skier animation

The production skier uses [full-curve motion](STEEP_MOTION_GAMEPLAY.md), constrained
by [connected articulation and the deep-tuck correction](SKIER_ANATOMY.md).
The original procedural layer remains available as a presentation fallback.
The solver owns the physics version; replay is v4. Cosmetic animation cannot
change either identity.

## Ownership

The custom 120 Hz solver owns root motion, ski contact, physical body state and
manual airborne rotation. Motion sampling reads completed state and shared landing
prediction. Render interpolation cannot advance the solver or write grip, COM,
pressure, reserve damage or replay snapshots.

The production character is the single final skeleton writer. Root/equipment,
physical ski bindings and motion snapshots share one render fraction. A shared
pelvis and constrained limb fitting keep boots attached while preserving bone
lengths and connected joints. Poles stay in the glove grip. The anatomical envelope
limits twist and grab reach rather than forcing unreachable hand contact.

Pause collapses interpolation and freezes phases. Restart clears state; crash
handoff transfers the completed pose and physical momentum to Jolt. See
[ski attachment](SKIER_PHYSICS.md#ski-attachment-and-render-timing).

## Motion and authoring

`presentation/skier_full_motion.gd` reads 33 retargeted clips from
`assets/animation/steep_ski_motion.res`. Support-relative local body shape is used;
source root translation, world bank and heading are not reapplied. Gameplay
weights reflect steering, speed, slip, tuck, support, jump readiness and impacts.
The mapping is an Apex design, not a reconstruction of Steep's complete runtime.

`presentation/skier_animation.gd` and `skier_animation_tuning.gd` own the procedural
layer. Editable profiles and measurement provenance live in
`art_source/animation/apex_ski_v17/`; `scripts/art/build_ski_motion.py` rebuilds those
profiles. Runtime full-curve import/build instructions are in
[full-curve gameplay](STEEP_MOTION_GAMEPLAY.md).

The [skier](SKIER.md) and [equipment](EQUIPMENT.md) pages identify the editable
body/equipment assets. Keep immutable source files and authoring manifests in
`art_source/`; put exploratory exports and captures in `artifacts/`.

## Validation

Run focused motion, anatomy, attachment and lifecycle suites for the changed
layer, plus physics/runtime suites when physical input or session behavior changes.
Inspect continuous native motion for carve/reversal, deep tuck, preparation,
flight, clean/awkward landing, switch, grab/release, crash and restart.

Numerical attachment or bone-length passes cannot establish believable motion.
The user rejected the first full-curve fit despite those checks, which is why
connected articulation and bounded twist/reach remain explicit constraints.
Camera comfort, skiing feel and performance require their own evidence. See
[validation](VALIDATION.md) for current acceptance and output lifecycle.
