# Current backlog

Groomed against **Dev75 / c53c28e6**, 16 September 2026. This is an index;
status, dependencies, evidence and acceptance live in each stable task record.
No workers or game benchmarks were started by grooming.

## Performance and integration

| Task | Remaining question |
|---|---|
| [Windows integration of Fable's work](tasks/AA-20260916-215944-verify-fable-windows-integration.md) | One owner for DX12 foliage/cloud rendering, interface and streaming checks left by Mac delivery. |
| [Collision and scenery stalls](tasks/AA-20260913-141128-reduce-forest-publication-and-collision-bursts.md) | Long indivisible collision cooks/publication; investigate worker aborts from their actual logs. Grass packing and texture-loader work already shipped. |
| [Ten-ghost playback](tasks/AA-20260912-132147-reduce-ten-ghost-presentation-cost.md) | Reduce playback/track work; coarser ghost animation is authorized. Recording cadence/pose reuse already shipped. |
| [Cold ghost loading](tasks/AA-20260912-132147-reduce-cold-ghost-archive-load.md) | Remaining decode/validation delay after worker payload loading; independent of selector UI. |
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
| [Ghost selector and rendered fixtures](tasks/AA-20260912-132147-finish-ghost-selector-and-render-fixtures.md) | Automatic fastest 1–10, 4K input/empty-set behavior and useful contact/shadow views; no pole-task dependency. |
| [Natural forest distribution](tasks/AA-20260913-232221-natural-forest-generation.md) | The separately agreed 15% thinning/high-altitude distribution change; never mix it into a frozen FPS comparison. |
| [Sun-facing lens flare](tasks/AA-20260913-221134-sun-facing-lens-flare.md) | The agreed occlusion-aware optional visual feature. |

## Blocked work and resume conditions

- **[Pole transitions](blocked/AA-20260912-132147-finish-pole-transition-validation.md):** known shaft/clothing and downhill plant/cancellation failures. Needs an explicit retry and a bounded corrective candidate; original [pole feature](blocked/AA-20260911-183812-slope-limited-pole-pushing.md) stays blocked with it.
- **[Ghost parent](blocked/AA-20260911-220556-animated-ghost-snow-tracks.md):** selector, cold-load and playback follow-ups above own remaining work.
- **[Integration closure](blocked/AA-20260912-132147-close-eight-feature-integration-records.md):** waits for its pole/selector follow-ups; also reconciles the checkpointed [respawn](blocked/AA-20260911-221843-crash-location-respawn.md), [raised tracks](blocked/AA-20260911-225724-carving-raised-ski-tracks.md), [finish beam](blocked/AA-20260911-232811-taller-distant-finish-beam.md), [navigation beams](blocked/AA-20260911-232936-session-navigation-beams.md), [forest transparency](blocked/AA-20260912-004316-forest-transparency-strength.md) and [snow boundary](blocked/AA-20260912-005323-subtle-local-snow-boundary.md) records. Existing functional evidence is retained; unfinished gates are not passes.
- **[Scenery snow](blocked/AA-20260911-230603-scenery-snow-material.md):** implemented, with explicitly deferred cost acceptance. [Distant mountain shadows](blocked/AA-20260911-230604-scenery-mountain-shadows.md) waits on that prerequisite.
- **[Motion blur](blocked/AA-20260912-004402-scene-motion-blur.md):** shipped provisionally; remaining performance/visual qualification needs explicit resumption.
- **[Broad dense-GPU investigation](blocked/AA-20260912-105302-reduce-dense-scene-gpu-cost.md)** and **[CPU LOD selection](blocked/AA-20260914-094136-select-forest-lods-before-submission.md):** rejected/stopped approaches; resume only with a distinct measured hypothesis. Active narrow tasks do not reopen them.
- **[Metal frame floor](blocked/AA-20260916-181500-reduce-mac-metal-frame-floor.md):** needs Metal capture/counters or a concrete alternate attribution method; no more blind toggle matrices.

## Completed and abandoned

[Completed](completed/) contains delivered work and finished investigations,
including pelvis/native fitting, terrain queries and Fable's closed tasks.
[Abandoned](abandoned/) contains the existing retired records plus the superseded
repeatability-prerequisite campaign. Retirement is not success; history and
replacement links remain in the records.

## Rules for the next task

Use the [current economical policy](../docs/VALIDATION.md#reusable-baselines-and-experiment-budget):
one hypothesis/candidate, visually reject before timing, reuse a matching saved
reference and add a control only for a specific ambiguity. Skip manual hash
audits and broad matrices. Retain verified small CPU/GPU/loading gains even when
the main FPS bottleneck does not move; report the distinction. Small visual and
physics tradeoffs are authorized, with the 120 Hz solver and 4 m authority intact.
Runtime replay/cache compatibility checks remain required. These current user
directions supersede older fresh-baseline/pixel-exact wording in historical records.
