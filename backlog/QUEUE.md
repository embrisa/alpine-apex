# Current backlog

Focus: `tasks/`, `blocked/` and `ideas/`, as requested on 17 September 2026.
Finish active and blocked work before implementing ideas. This is an index;
status, dependencies, evidence and acceptance live in each stable task record.

## Performance and integration

| Task | Remaining question |
|---|---|
| [Collision and scenery stalls](tasks/AA-20260913-141128-reduce-forest-publication-and-collision-bursts.md) | Long indivisible collision cooks/publication; investigate worker aborts from their actual logs. Grass packing and texture-loader work already shipped. |
| [Powder update/shader cost](tasks/AA-20260916-084507-reduce-powder-patch-render-cost.md) | One remaining repeated-update or shader hypothesis; mesh subdivision reductions are complete. |
| [Sky, periphery and tracks](tasks/AA-20260916-084510-trim-environment-and-screen-passes.md) | One remaining measured pass; SSAO/SSIL defaults, cloud globals and far-track discard are complete. |

## Bounded rendering experiments

| Task | Remaining question |
|---|---|
| [Open-route terrain LOD](tasks/AA-20260916-084505-fix-terrain-mesh-lod-selection.md) | Open slope/ridge result; the dense-route bias candidate was rejected. |
| [Terrain occlusion](tasks/AA-20260914-094136-cull-scenery-behind-terrain.md) | Prior prototype needs a cost/visibility verdict; fewer draws did not establish FPS gain. |
| [Grouped distant stands](tasks/AA-20260914-094136-render-distant-forest-stands.md) | Must beat existing two-triangle far cards while preserving silhouettes. |

## Player features and art

| Task | Remaining outcome |
|---|---|
| [Natural forest distribution](tasks/AA-20260913-232221-natural-forest-generation.md) | The separately agreed 15% thinning/high-altitude distribution change; never mix it into a frozen FPS comparison. |
| [Sun-facing lens flare](tasks/AA-20260913-221134-sun-facing-lens-flare.md) | The agreed occlusion-aware optional visual feature. |

## Blocked work and resume conditions

- **[Pole feature](blocked/AA-20260911-183812-slope-limited-pole-pushing.md):** resolve the remaining contact and transition gaps within the current backlog-completion goal.
- **[Scenery snow](blocked/AA-20260911-230603-scenery-snow-material.md):** implemented, with explicitly deferred cost acceptance. [Distant mountain shadows](blocked/AA-20260911-230604-scenery-mountain-shadows.md) waits on that prerequisite.
- **[Motion blur](blocked/AA-20260912-004402-scene-motion-blur.md):** finish the remaining performance and visual qualification.
- **[Metal frame floor](blocked/AA-20260916-181500-reduce-mac-metal-frame-floor.md):** needs Metal capture/counters or a concrete alternate attribution method; no more blind toggle matrices.

## Ideas for the final phase

- [Load only the requested ghost count](ideas/IDEA-20260917-011800-load-only-requested-ghost-count.md).
- [Skip unchanged ghost material parameters](ideas/IDEA-20260917-013000-skip-unchanged-ghost-material-updates.md).

## Rules for the next task

Use the [current economical policy](../docs/VALIDATION.md#reusable-baselines-and-experiment-budget):
one hypothesis/candidate, visually reject before timing, reuse a matching saved
reference and add a control only for a specific ambiguity. Skip manual hash
audits and broad matrices. Retain verified small CPU/GPU/loading gains even when
the main FPS bottleneck does not move; report the distinction. Small visual and
physics tradeoffs are authorized, with the 120 Hz solver and 4 m authority intact.
Runtime replay/cache compatibility checks remain required. These current user
directions supersede older fresh-baseline/pixel-exact wording in historical records.
