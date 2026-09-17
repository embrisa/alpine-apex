---
id: "AA-20260911-230604-scenery-mountain-shadows"
title: "Add time-dependent distant mountain shadows with scalable settings"
status: done
priority: P2
depends_on: ["AA-20260911-230603-scenery-snow-material"]
created: "2026-09-11T23:06:04Z"
updated: "2026-09-17T16:43:29.069562+00:00"
source_thread: "01a092b4-c1a2-7d50-a577-a5e08a7f15d8"
---

# Add time-dependent distant mountain shadows with scalable settings

## Current disposition — 17 September 2026

Delivered as a saved Off/Low/High scenery setting. All ten presets remain Off.
Matched native visual review passed; one warmed 15-second dusk comparison measured
146.19 / 144.72 / 144.82 average FPS for Off/Low/High. High added 0.0647 ms mean
frame time; Low had worse tails in its single sample. These are optional feature
costs on the open upper route, not dense-forest acceptance. Human preference stays
separate. The current economical policy replaces the original repeated full-run
matrix; the completed checks and limitations are recorded below.

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
[prerequisite](../completed/AA-20260911-230603-scenery-snow-material.md).
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

Own offline baking in `scripts/authoring/`, optional companion payload/version/
provenance in `wilderness_horizon_asset.gd`, selected load/texture lifecycle in
`wilderness_horizon.gd`, and evaluation in the shared off-map shader. Integrate live direction through the existing
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

- [x] After prerequisite completion, capture matched Off/on summit, valley,
  apron and moving skiing views. Broad shadows visibly track changing sun
  azimuth/elevation, agree with blocking ridges and remain stable at low sun,
  night/moon, weather changes and across connector/quality transitions.
- [x] Automated directional fixtures cover unobstructed slopes, a known ridge
  and valley, day/night transitions, finite values, determinism, all asset tiers
  and representative connector seeds. Test changed payload integrity/versioning
  and export dependencies, including bounded loading and cancellation.
- [x] Run focused native compilation/rendered checks and relevant suites using
  `./scripts/test_pc_environment.ps1 -Suites
  graphics_suite,pc_graphics_suite,graphics_override_suite,wilderness_suite,offmap_geometry_suite,offmap_atmosphere_suite,offmap_lifecycle_suite,scenery_loading_suite`
  as one command. Add targeted bake/cache tests as needed. This wrapper owns the
  guard; all other engine/bake workloads use `scripts/run_guarded.ps1` serially.
- [x] Verify settings persistence, preset/reset behavior, same-tier changes,
  late-created scenery, cheap Off behavior and unchanged gameplay shadow range.
  Test profiles remain isolated and unranked.
- [x] Under the current economical policy, measure one current 15-second
  ordinary-input open-route dusk arm per Off/Low/High after an excluded warmup:
  4K/High/Auto75%, FG/GI off, identical source/camera/weather. Inspect frame/GPU
  median and p95/p99, rendered FPS, CPU, companion loading, memory and offline
  bake cost. Keep all presets Off; distinguish shared startup from incremental
  shadow cost and engine allocation counters from physical VRAM. This replaces
  the older automatic three-repeat full-descent matrix.
- [x] Record exact reproduction commands, versions, paths, settings and scoped metadata and
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

Delivered in Dev100 (the commit containing this record and
`changes/e4bc3cfb98ed4f90a98550ab6a189a32.json`), after Dev99 scoped benchmark
metadata. Production terrain, placement, base scenery bytes, UIDs and gameplay
identities are preserved. Six optional version1 companions match all three
resident geometry tiers. Variable central-mountain cast shadows are intentionally
omitted: exclude occluders inside3900m, fade receivers3900-4300m outside the maximum
3780m connector bound. Direct light only; ambient/cloud/fog ownership retained.
Off releases CPU images/GPU texture, performs no angle calculation or texture
sampling, and never bakes. Newest quality wins during staged replacement.

- **Automated:** 354 unique relevant checks passed, plus native shader/harness
  compile and Python directional/finite/determinism/exclusion fixtures. Both
  current connector seeds tested. The missing second fixture was explicitly
  prepared once after the suite safely stopped. Export dependencies refreshed
  through the maintained producer; no packaged-executable qualification claimed.
- **Rendered:** 27 matched stills covering day/dusk/moon/cloud, connector and all
  geometry tiers; 16 camera poses and24 ordinary-input skiing poses per Off/High.
  No obvious seams/grid sliding in review. These are chronological poses, not
  real-time/controller acceptance. The down-facing labelled valley shot is weak
  distant evidence; the outward4050m connector shot supplies valley/prop coverage.
- **Performance:** one 15-second clear/dusk arm per mode, native RX9070,4KHigh,
  Auto0.75 FSR4.1.1, FG/GIoff. Off146.19FPS/6.8403ms; Low144.72/6.9101ms;
  High144.82/6.9050ms. GPU median5.2280/5.1990/5.3285ms. Frame p95/p99:
  8.750/9.803,9.270/12.274,8.758/9.764ms. No causal claim for the single Low tail
  regression and no dense-route improvement claim. All presets remain Off.
- **Loading/memory:** Low0.5MiB/High4MiB raw image payload plus matching GPU
  texture. Initial selection CPU1.819/9.637ms, six-map offline bake21.020s,
  compressed companions8.44MB. Shared warm startup and engine allocation
  counters are recorded separately; cold startup/physical VRAM not isolated.
- **Evidence/docs:** [compact report](../../artifacts/scenery_mountain_shadows/REPORT.md),
  summary.json, final_pairs.jpg, motion_pairs.jpg, selected raw final_review
  captures and native timing under artifacts/pc_environment/scenery_horizon_cost_final/.
  Scoped size/mtime inputs remained stable, exact states matched and focus loss0.
  Rendering/Assets/World/Validation and both affected skills updated.

Human scenery preference and controller comfort remain pending separately.
No new follow-up idea was required. Reproducible intermediates are retired after
push; useful compact evidence and final source assets remain.
