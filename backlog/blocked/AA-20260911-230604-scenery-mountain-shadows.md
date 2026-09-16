---
id: "AA-20260911-230604-scenery-mountain-shadows"
title: "Add time-dependent distant mountain shadows with scalable settings"
status: blocked
priority: P2
depends_on: ["AA-20260911-230603-scenery-snow-material"]
created: "2026-09-11T23:06:04Z"
updated: "2026-09-16T21:59:44Z"
source_thread: "01a092b4-c1a2-7d50-a577-a5e08a7f15d8"
---

# Add time-dependent distant mountain shadows with scalable settings

## Current disposition — 16 September 2026

The agreed feature is blocked on completion of the scenery-snow cost
gate. It is optional visual work after the performance/correctness groups in the
queue index. Resume when that prerequisite is delivered or its cost gate is explicitly waived. Do not turn the blocked prerequisite into a full benchmark campaign;
its older repetition/hash recipe is superseded by the economical policy.

## Outcome

Give distant snowy valleys and ridges convincing broad shadows that respond to
the current light direction. Evaluate the result after the material improvement,
so its additional benefit and cost are visible. The user explicitly requires
settings for additions with a large performance impact.

## Current state and evidence

Source inspection at `9f687775e53c229ffb858f1dcbdcb0f57313ae10` found that
[wilderness rendering](../../scripts/world/alpine_wilderness.gd) disables shadow
casting/GI and its [shader](../../assets/graphics/alpine_wilderness.gdshader)
disables shadow reception. The distant branch of
[shared lighting](../../assets/cloud_light.gdshaderinc) omits ordinary shadow
attenuation. Slope-facing light is present; ridge-to-valley occlusion is absent.

The [authored scenery resource](../../scripts/world/wilderness_asset.gd) is reused
with a mountain-specific connector. It spans an 18 km horizon, making extension
of ordinary gameplay shadow maps an unsuitable default approach. These are
source findings; no shadow solution or cost has yet been measured.
Read [Rendering](../../docs/RENDERING.md), [World](../../docs/WORLD.md),
[Assets](../../docs/ASSETS.md), [Validation](../../docs/VALIDATION.md) and the
[prerequisite](AA-20260911-230603-scenery-snow-material.md).
Coordinate current interfaces with the independent
[weather task](../abandoned/AA-20260911-160307-weather-upgrade-storm-races.md); do not implement
its weather/race design here.

## Agreed decisions and scope

- Use precomputed terrain horizon/occlusion information evaluated against the
  active directional light. Do not bake fixed noon shadows into snow colour.
- Provide an explicit saved **Distant mountain shadows** control with Off and
  bounded quality choices. It is independent of playable shadow distance,
  terrain GI and the prerequisite's snow detail. Off keeps the improved scenery.
- Default Low/Balanced to Off. High may enable a bounded tier only with measured
  negligible cost; otherwise default Off and expose higher quality as opt-in.
  A repeatable increase of at least 0.5 ms median GPU time or 5% frame p95/p99
  against Off is a conservative mandatory opt-in trigger, not an allowed hidden
  regression. Account for startup and memory too. Record measured choices.
- Preserve presentation-only ownership, authored terrain/prop layout, physical
  terrain/solver/race identity, and the $5/month hard LFS cap. Do not extend
  ordinary real-time shadow casting/GI across the entire background.

## Implementation approach

Prototype a bounded directional horizon bake on the authored wilderness height
surface. Store light-independent obstruction angles or equivalent directional
data; compare with current sun/moon direction at runtime with stable filtering
and a soft transition. Validate occlusion against actual rendered ridges: overly
coarse horizons must not create floating, leaking or inverted shadows.

Own offline baking in `scripts/authoring/`, payload/version/provenance in
`wilderness_asset.gd`, load/cache handling in `wilderness_data.gd`, and evaluation
in the shared off-map shader. Integrate live direction through the existing
weather/cloud interface. Attenuate direct light only, preserve ambient fill, and
compose existing cloud dimming/fog without double-darkening or night emission.

Handle the connector explicitly: fixed-resource data does not describe its
mountain-dependent deformation. Prepare bounded connector data during scenery
preparation or blend to a validated conservative result through the collar;
do not ray march/rebake terrain every frame. Seam, night, low-sun and quality
transition behavior must be deliberate. Do not change physical generation.

Version any new authored/cache payload and update dependency/export manifests;
reject/regenerate incompatible scenery data without legacy shims. Author offline
assets explicitly, never through startup or quality switches. Preserve source
receipts, existing UIDs/import settings and unrelated assets. Bind settings through
the existing graphics preset/override system, with live updates, reset, reload
and newly staged scenery supported. Off must skip evaluation and avoid optional
resource residency where practical; quality changes cannot trigger long rebakes.

## Acceptance and verification

- [ ] After prerequisite completion, capture matched Off/on summit, valley,
  apron and moving skiing views. Broad shadows visibly track changing sun
  azimuth/elevation, agree with blocking ridges and remain stable at low sun,
  night/moon, weather changes and across connector/quality transitions.
- [ ] Automated directional fixtures cover unobstructed slopes, a known ridge
  and valley, day/night transitions, finite values, determinism, all asset tiers
  and representative connector seeds. Test changed payload integrity/versioning
  and export dependencies, including bounded loading and cancellation.
- [ ] Run focused native compilation/rendered checks and relevant suites using
  `./scripts/test_pc_environment.ps1 -Suites
  graphics_suite,pc_graphics_suite,graphics_override_suite,wilderness_suite,offmap_geometry_suite,offmap_atmosphere_suite,offmap_lifecycle_suite,scenery_loading_suite`
  as one command. Add targeted bake/cache tests as needed. This wrapper owns the
  guard; all other engine/bake workloads use `scripts/run_guarded.ps1` serially.
- [ ] Verify settings persistence, preset/reset behavior, same-tier changes,
  late-created scenery, cheap Off behavior and unchanged gameplay shadow range.
  Test profiles remain isolated and unranked.
- [ ] Measure Off versus each quality tier separately from capture, using the
  current valid ordinary-input full-descent trace and Validation performance
  method: 4K/High/Auto 75%, FG/GI off, at least three repetitions, identical
  camera/weather/source/engine. Include shadow-heavy low-sun views as additional
  cases. Record frame/GPU median and p95/p99, rendered FPS, CPU, memory, bake,
  cache-load and scene-readiness costs. Apply the opt-in gate above; a capped
  summit benchmark alone cannot establish acceptable cost.
- [ ] Record exact reproduction commands, source/asset/runtime hashes and
  before/after evidence under `artifacts/scenery_mountain_shadows/`. Update the
  owning Rendering guide and relevant asset/cache contracts without duplicating
  reports. Validate backlog, commit/push owned source and required baked assets.

Human acceptance: visual preference and controller comfort remain separately
pending follow-up, not a worker-completion gate. Worker-rendered and performance
acceptance are required; if the approach cannot produce stable useful shadows
within bounded optional quality, record the blocker rather than claim delivery.

## Open questions

None.

## Completion record

Pending implementation. Record outcome, verification actually performed, quality
costs/defaults, remaining human acceptance, updated docs and commit/push references.
If blocked, record the limitation and unfinished work. Link separate next-step
ideas, or state none were proposed.
