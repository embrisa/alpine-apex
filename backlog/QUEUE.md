# Current backlog

Focus: `tasks/`, `blocked/` and `ideas/`, as requested on 17 September 2026.
Finish active and blocked work before implementing ideas. This is an index;
status, dependencies, evidence and acceptance live in each stable task record.

## Player features and art

| Task | Remaining outcome |
|---|---|
| [Sun-facing lens flare](tasks/AA-20260913-221134-sun-facing-lens-flare.md) | The agreed occlusion-aware optional visual feature. |

## Blocked work and resume conditions

- **[Grouped distant stands](blocked/AA-20260914-094136-render-distant-forest-stands.md):** user approved timing; both the pictured patch and complete-cell test show no FPS gain. Resume with a different representation that lowers total GPU/frame cost.
- **[Pole feature](blocked/AA-20260911-183812-slope-limited-pole-pushing.md):** resolve the remaining contact and transition gaps within the current backlog-completion goal.
- **[Scenery snow](blocked/AA-20260911-230603-scenery-snow-material.md):** implemented, with explicitly deferred cost acceptance. [Distant mountain shadows](blocked/AA-20260911-230604-scenery-mountain-shadows.md) waits on that prerequisite.
- **[Motion blur](blocked/AA-20260912-004402-scene-motion-blur.md):** finish the remaining performance and visual qualification.
- **[Metal frame floor](blocked/AA-20260916-181500-reduce-mac-metal-frame-floor.md):** MacBook unavailable, confirmed by the user on 17 September. Resume with machine access and Metal counters or a concrete alternate attribution method.

## Ideas for the final phase

- [Load only the requested ghost count](ideas/IDEA-20260917-011800-load-only-requested-ghost-count.md).
- [Skip unchanged ghost material parameters](ideas/IDEA-20260917-013000-skip-unchanged-ghost-material-updates.md).
- [Separate scenery bake inputs from render-only updates](ideas/IDEA-20260917-082200-separate-scenery-bake-dependencies.md).
- [Share far-tree material submissions](ideas/IDEA-20260917-090000-share-far-tree-material-submissions.md).

- [Use scoped benchmark metadata](ideas/IDEA-20260917-110000-use-scoped-benchmark-metadata.md).

## Rules for the next task

Use the [current economical policy](../docs/VALIDATION.md#reusable-baselines-and-experiment-budget):
one hypothesis/candidate, visually reject before timing, reuse a matching saved
reference and add a control only for a specific ambiguity. Skip manual hash
audits and broad matrices. Retain verified small CPU/GPU/loading gains even when
the main FPS bottleneck does not move; report the distinction. Small visual and
physics tradeoffs are authorized, with the 120 Hz solver and 4 m authority intact.
Runtime replay/cache compatibility checks remain required. These current user
directions supersede older fresh-baseline/pixel-exact wording in historical records.
