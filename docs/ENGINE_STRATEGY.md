# Godot development and performance strategy

## Direction

Keep Godot as Alpine Apex's engine and development environment. Improve its
use and extend it where the game benefits: efficient game code, native C++
components, lower-level engine APIs and focused engine-source changes are all
valid parts of this direction. A full replacement runtime is outside the current
roadmap; ordinary feature and performance work should not prepare an engine rewrite.

The goal is responsive skiing, richer mountains, short waits and consistent
frame times on the target PC. Make the most of Godot against those goals, with
measured gains and manageable maintenance cost. There is no requirement to
optimize every subsystem indefinitely or convert the whole game to C++.

## Apply this during ordinary development

When working on generation, loading, terrain, scenery, simulation performance,
audio or engine integration:

1. Read the relevant subsystem's current implementation and evidence. Earlier
   reports and the opportunities below are investigation leads; a later task
   may already have improved them.
2. Look for related repeated work, allocations, expensive data layouts,
   unnecessary engine submissions and blocking preparation. Implement a small,
   useful improvement within the task when evidence supports it. Do not turn
   an unrelated feature request into a broad performance project.
3. Choose the smallest effective change. Algorithm/data changes, caching,
   parallel jobs and native code can be combined; there is no obligation to
   exhaust every GDScript optimization before using a well-justified C++ component.
4. Compare the affected workload before and after, run appropriate correctness
   checks, and inspect rendered behavior when presentation changes. A faster
   isolated operation needs an integration check for its intended benefit.
5. Update the subsystem page with the outcome and remaining bottleneck. For a
   larger follow-up, record the observed cost, reproduction method, proposed
   next step and acceptance measure there. Link it from the roadmap if it changes
   priorities. Keep this page as strategy, rather than a duplicate results log.

Continue incremental improvement across tasks. Retire disproven ideas and
completed work from active recommendations; retain useful reasoning in the
subsystem documentation. Major systems still need the gameplay purpose,
architecture and material risks explained before implementation, as required by
[AGENTS.md](../AGENTS.md).

## Choose the appropriate implementation level

| Level | Use when | Boundaries |
|---|---|---|
| GDScript and existing Godot facilities | Removing duplicate work, improving algorithms, batching, caching or scheduling addresses the cost | Keep ordinary gameplay and tools easy to iterate on; reduce work before merely moving it |
| C++ through GDExtension | CPU-heavy array processing, generation, geometry preparation or audio has a demonstrated benefit from compiled code | Pass whole arrays/chunks and run substantial work per call; account for conversion, copying, allocation and packaging costs |
| Lower-level Godot APIs | Scene or resource submission overhead remains significant | Use targeted server/buffer APIs within the existing world; document resource ownership, lifetime and synchronization |
| Focused Godot engine changes | Required renderer access or a measured engine limitation cannot be addressed cleanly through extension APIs | Keep a narrow patch, reproducible build, pinned dependencies and validation tied to the actual executable |

Native wind synthesis in [WIND_DSP.md](WIND_DSP.md) and the modified Godot DX12
renderer in [FIDELITYFX.md](FIDELITYFX.md) demonstrate the extension and engine
approaches. In this project, that document's custom engine is a customized Godot
build. Reuse established build and validation procedures where applicable.

Godot supports [native extensions](https://docs.godotengine.org/en/4.4/tutorials/scripting/gdextension/what_is_gdextension.html)
and [server APIs](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html).
Check the API and [thread-safety constraints](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)
against the project's active engine before implementation. Prepare immutable data
off the main thread where appropriate; coordinate scene changes and GPU uploads
through supported engine paths. Threading alone does not remove synchronization
stalls or GPU upload costs.

## Opportunities to revisit when touching a subsystem

These are candidates to verify against current code and measurements, not claims
that each problem is still present or commitments to implement every option.

| Area and entry point | Useful improvements to investigate | Acceptance focus |
|---|---|---|
| Generation: [current mountain](PLANTED_SNOW.md), [terrain and density](ALPINE_V13.md) | Packed populations, spatially indexed placement/filtering, reused surface calculations, deterministic tiled snow/geology jobs; move expensive kernels into C++ when warranted | Cold time, stage/work counts, achieved population, peak memory, seating and repeatability across seeds and worker counts |
| Loading/cache: [mountain lifecycle](MOUNTAINS.md) | Cache final material/collision preparation and reusable visual preparation; use bounded packed sections, validated identities and atomic publication; avoid repeated whole-payload serialization | Warm reconstruction and total time to ski, disk/memory budgets, invalidation, cancellation and exported-build behavior |
| Terrain construction: [graphics](GRAPHICS.md) | Precompute normals, reuse triangle/LOD index templates, prepare chunk arrays in jobs and batch uploads; stage visible construction without long blocking operations | Preparation versus scene/upload time, responsive loading, memory peaks and agreement with the support surface |
| Forests/scenery: [FPS optimization](FPS_OPTIMIZATION.md) | Reuse packed transforms and conservative bounds, remove unused grouping, bound nearby detail residency, reduce material/submission churn and improve visibility batching | Dense-area CPU/GPU p95/p99, draw calls, upload volume and stable memory during repeated travel |
| Simulation/contact: [architecture](ARCHITECTURE.md) | Reduce hot-path allocations and redundant terrain queries; extract a coherent native calculation core if actual solver cost warrants it | Same intended 120 Hz behavior, terrain/contact tests, repeatability and physics/runtime regressions |
| Audio: [wind DSP](WIND_DSP.md), [skiing audio](SKIING_AUDIO.md) | Keep costly sample processing in native audio callbacks; use bounded state exchange from gameplay | Callback cost, lifecycle correctness and actual listening/device acceptance |
| Renderer: [graphics policy](GRAPHICS.md), [FidelityFX](FIDELITYFX.md) | Profile visibility, detail levels, shadow work, overdraw, shader cost and submission; consider deeper terrain/forest integration only for a demonstrated remaining limit | Complete rendered descents at matched settings, temporal quality, hardware behavior and ongoing engine maintenance |

Richness increases need their own capacity and route validation. Requested object
counts may exceed what spacing and protected areas permit. If generation settings
change physical output, include canonical settings in recipes, cache keys and
race/mountain identity; seed alone is insufficient. Improving performance does
not by itself authorize a new richness preset, map size or physical surface.

## Measure the outcome the player experiences

Separate cold generation, warm physical-cache reconstruction, visual preparation,
scene/GPU submission, complete time to ski and steady-state skiing. Faster
generation does not establish higher rendered FPS; a cache hit does not establish
fast scene construction. CPU savings do not remove an unrelated GPU bottleneck.

Use [graphics policy](GRAPHICS.md#performance-policy) and the current
[matched-descent procedure](FPS_OPTIMIZATION.md). The target remains Ryzen 5
5600X / RX 9070 / 16 GB, 3840x2160 output, 90-120 rendered FPS, p95 <= 11.1 ms
and p99 <= 16.7 ms. Use the documented High configuration and record actual
internal/output dimensions, engine/source identity and graphics settings.
Generated frames remain separate from rendered performance.

For performance claims, report relevant stage times, CPU/GPU timings, frame
distributions including dense sections, and peak/resident RAM and available GPU
memory counters. Repeat comparisons enough to distinguish improvement from run
variation. Use the shared validation guard and keep engine workloads sequential.
Quality reductions and density changes must be identified as tradeoffs and
measured separately from equivalent-output optimizations. No fixed speedup is
promised by a language change, threading or engine modification.

## Preserve game authority and scope

The custom ski solver remains independent of Nodes and rendering at 120 Hz. It
currently uses GDScript and Godot types; Node independence does not make it an
already portable library. Preserve clear calculation boundaries, but avoid a
generic engine-abstraction layer or wholesale solver port without a current need.

Terrain, contact, tracks, survey and crashes continue to share the authoritative
4 m support surface. Parallel jobs must use stable random streams, immutable
inputs and deterministic conflict/commit order where physical output depends on
ordering. Visual detail, graphics quality, audio and generated frames cannot
change simulation state or randomness. Validate or version physical identities
when algorithms change them; follow the early-development compatibility policy.

Keep one production terrain rendering path, the Godot editor/import workflow and
the MCP toolkit. Changes may improve the existing mesh path; they should not add
a competing terrain authority or speculative second renderer. A full standalone
runtime would require a separately revisited project direction. Its development
and maintenance cost is outside this incremental roadmap.

Automated correctness, rendered inspection, measured performance and the user's
skiing, visual, controller and listening acceptance remain separate.

## V15 measured generation work

[V15](GENERATION_V15.md) implements packed populations, indexed immutable stages,
bounded Godot workers and separate physical/scenery caches without an engine or
native-extension rewrite. Matched cold Standard generation improved from 422.634 s
to 130.843 s mean; complete cached rendered time to ski is measured separately.
Remaining measured costs are main-thread mineral/forest submission, asset identity
reads and serial geology/seating. Static dense-frame evidence remains distinct
from full-descent performance and player acceptance.
