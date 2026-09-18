---
id: "AA-20260918-011208-add-ridge-crest-spindrift-plumes"
title: "Blow spindrift off ridges and crests in wind"
status: ready
priority: P3
depends_on: []
created: "2026-09-18T01:12:08Z"
updated: "2026-09-18T08:40:00Z"
source_thread: null
---

# Blow spindrift off ridges and crests in wind

## Outcome

In strong wind, snow should stream off ridges, cornices and rollovers ahead of the
rider, the way it does on a real mountain. Today wind is visible in the trees,
the clouds and the grass, but the snow surface itself never moves, so the mountain
looks still even in a storm.

## Current state and evidence

Read-only inspection and bounded rendered macOS probes on 2026-09-18 at `main` `7c2d049`. Probe captures used `scripts/mac_frame_probe.sh` with the deterministic `--probe-hold`/`--probe-at-tick` options; the Standard fixture (seed 849205174) was rebaked because the local cache was `mountain_cache_v15` against current `mountain_cache_v17`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy); they indicate direction only.

- A spindrift field already exists and is fully plumbed:
  [`weather_preset.gd`](../../scripts/presentation/weather_preset.gd) exports
  `spindrift` at 0.18 for Clear, `weather_state.gd` blends it across fronts, and
  [`weather_effects.gd`](../../scripts/presentation/weather_effects.gd) drives its
  opacity as `state.spindrift*(0.18+state.gust*0.20)`.
- It is rider-local only. The same file gates emission on
  `absf(rider_position.y-height)<7.0`, so it is a thin ground-level layer that
  follows the rider and is never seen as a plume off distant terrain.
- The draw path already distinguishes it:
  [`weather_particle_draw.gdshader`](../../assets/weather_particle_draw.gdshader)
  carries `kind` 2 for spindrift, and
  [`snow_spray.gdshader`](../../assets/graphics/snow_spray.gdshader) gives that
  kind a reduced alpha of .18.
- Wind is already a shared registry consumed by trees, grass and the cloud field,
  so a plume would read as part of the same weather rather than a separate effect.
- [Rendering](../../docs/RENDERING.md#weather) records the hard boundaries:
  precipitation uses translation-only local volumes with wrapping and retained
  particle state, bounded ground samples replace per-particle CPU collision, and
  budgets cap at 1,700 High and 850 Low particles. There is deliberately no
  precipitation accumulation, no wet-grip model and no physical wind force.

## Agreed decisions and scope

- Settled with the user on 2026-09-18: the effect is wanted, and plumes may
  appear in every weather including Clear, where `spindrift` already defaults to
  0.18. This is the first implementation; narrowing it to Cloudy and above stays
  available if Clear-weather plumes prove distracting in playtest.
- Presentation only, in the strongest sense. No accumulation, no physical wind
  force, no shelter model and no change to grip, support or the snow contact
  contract. Those would require explicit physical and race contract changes.
- Must come out of the existing weather particle budget and quality controls, or
  state plainly what new budget it needs and why. It must respect Reduced Motion
  and the precipitation quality control, including quality zero disabling it.
- Must be driven by the existing wind and spindrift weather state rather than a
  new independent animation, so it agrees with the trees, grass and clouds.
- Must not obscure the line ahead. A plume that hides terrain the rider is about
  to cross is a readability failure regardless of how it looks.
- Out of scope: the rider-local spindrift layer, which keeps its current owner and
  behaviour, and precipitation appearance generally.

## Implementation approach

1. Decide where plumes may appear from data the world already has. Ridge crests
   and convex rollovers are derivable from the immutable support heights that
   [`snow_readability.gd`](../../scripts/presentation/snow_readability.gd)
   already analyses once per world during scenery preparation; reuse that pattern
   rather than analysing terrain while skiing.
2. Bound residency hard. Only crests within a stated distance of the camera and
   facing the wind should emit, with a fixed cap, following the existing
   translation-only volume and wrapping rules.
3. Drive intensity from the existing `spindrift` and `gust` state so it rises and
   falls with the front, and reuse the `kind` 2 draw path rather than adding a
   shader.
4. Reject visually before timing. If the plumes cannot be made to read well
   without obscuring the line, record that and stop; this is a P3 flourish, not a
   correctness fix.

## Acceptance and verification

- [ ] Captures in calm, windy and storm weather show plumes that appear, intensify
  with gusts and disappear with the front, agreeing with tree and grass wind.
- [ ] The line ahead stays readable at racing speed; verify at first-person and
  chase views at high speed through a gusting front.
- [ ] Reduced Motion, precipitation quality zero and Low preset behaviour are
  correct; the effect is fully removable.
- [ ] Teleport, retry, crash, pause and camera transitions reset plume state
  cleanly, matching the existing precipitation reset rules.
- [ ] Particle counts stay within the stated budget; report the actual counts.
- [ ] Bounded warmed before/after frame comparison in storm weather, which is the
  worst case, with the noise floor stated.
- [ ] Update [Rendering](../../docs/RENDERING.md#weather) and validate the backlog.

Human acceptance: a completion gate. This is an atmosphere feature and only the
user can say whether it reads as the mountain or as clutter.

## Open questions

None.
## Completion record

Pending implementation.

