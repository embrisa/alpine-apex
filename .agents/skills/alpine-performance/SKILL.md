---
name: alpine-performance
description: Measure and improve Alpine Apex frame time, CPU/GPU cost, loading, generation or streaming performance. Use for bottleneck attribution and controlled before/after experiments that preserve the requested gameplay and visual quality. Routine test timing alone is not performance acceptance.
---

# Alpine performance

Read the current [performance policy](../../../docs/RENDERING.md#performance-policy),
[measurement method](../../../docs/VALIDATION.md#performance-method) and
[engine strategy](../../../docs/ARCHITECTURE.md#engine-strategy). Follow the user's
requested conditions and the owning subsystem guide. State the cost being
investigated and its unit before launching: rendered frame time, fixed-tick CPU,
GPU pass, loading stage, cold preparation or streaming hitch.

## Establish a valid experiment

1. Identify the exact source and runtime through
   [engine selection](../../../docs/DEVELOPMENT.md#checkout-and-engine-selection).
   Record dirty input hashes where relevant, recipe/seed/model, trace, cache
   state, camera, actual output pixels and effective settings. Verify identities
   from current producers rather than historical filenames or benchmark defaults.
2. Choose the shortest representative scenario under
   [bounded descents](../../../docs/VALIDATION.md#bounded-test-descents). Use the
   supported ordinary-input replay for gameplay measurements. For loading or
   generation, measure the relevant stages and requested populations directly;
   a warm-cache run cannot establish cold-generation improvement.
3. Collect a fresh baseline before edits. Use the guide's independently warmed
   repetitions for comparisons. Separate setup/pre-roll from measured riding and
   define a clean stop. Preserve the selected quality, scenery, effects, physics
   and input behavior unless the user explicitly requests those tradeoffs.
4. Secure uncontended measurement time and stable inputs. Follow the existing
   [ownership protocol](../../../backlog/OPERATIONS.md#file-reservations-and-fps-sensitivity)
   when scheduled workers are involved; manual agents do not take scheduled
   claims. Run measurements with `-WorkloadMode FpsCritical`; a queued exclusive
   lease drains existing shared runs and blocks new ones. Functional checks can
   use `Shared`, but their contended timings cannot establish performance.
   Never nest guards or bypass a waiting measurement. If timing is blocked,
   continue independent non-timing work that does not disturb the measured system.

For validation turnaround, follow [targeted maps](../../../docs/VALIDATION.md#targeted-test-maps)
and measure setup and complete-check wall time separately. Small-fixture timing
cannot establish production FPS. Production mountain benchmarks require both
`-FullMountain` and a recorded `-FullMountainReason` at the owning guard; missing
archives require explicit preparation rather than an implicit cold bake.

## Attribute and change

For local slopes, rocks, vegetation or combined rendering, use the
[targeted FPS maps](../../../docs/VALIDATION.md#targeted-rendering-and-fps-maps):
`scripts/benchmark_targeted.ps1 -Map vegetation -PlanOnly`, then a fresh output
for measurement. Select the corresponding component map; `mixed` combines the
same placements. The wrapper owns FpsCritical admission and three independent
short trials by default. Capture separately with `-Capture`; inspect detail and
overview images. The targeted wrapper defaults to its explicitly recorded
`-Camera scenery` profile; compare it only with the same framing. Use `-Camera riding`
to inspect the existing riding configuration. Neither profile writes preferences.
Read actual population, pixels, complete duration, source/focus
validity and per-trial frame tails. These are local production-component results;
keep full-mountain FPS and human acceptance separate.
When concurrent source edits invalidate a forest baseline, use the explicit
[frozen forest comparison](../../../docs/VALIDATION.md#colorful-tree-checks)
with an identified pre-change revision. Inspect its enumerated overrides and
before/after binary hashes; do not silently reinterpret a drifting run as valid.

Use [benchmark_pc.ps1](../../../scripts/benchmark_pc.ps1) for production frame
measurements; consult the measurement guide for its guarded invocation. Select
an explicit compatible `-InputTrace`, event window, fresh `-Label`, repetitions
and effective settings. Do not rely on its historical default trace path.
For terrain grass, follow the [grass comparison](../../../docs/VALIDATION.md#terrain-grass-performance):
`-Grass off` isolates ground and mineral grass only. Validate zero/off and
nonzero/on populations, unchanged effective settings and identical final states.
Local ordinary traces require explicit scenario playback; they cannot establish
complete-descent or stress-driver acceptance. Use fresh producer-identified
traces, and reject surviving obstacle contacts for the clear grass workloads.
Use `-ProfileFrameCosts` for CPU attribution and the
[GPU attribution route](../../../docs/VALIDATION.md#native-gpu-pass-attribution)
only when GPU pass evidence is needed. Capture visual comparisons separately
from timing; readbacks, screenshots and encoding can alter the measured cost.

Use a focused harness for isolated kernels or preparation stages, then validate
the result in the affected production path before claiming gameplay benefit.
Inspect cost units and cadence: overlapping fixed-tick, render-pose and GPU
measurements cannot simply be added. Disabled-feature probes can help attribute
cost, but acceptance uses the requested production configuration.

Form a specific bottleneck hypothesis and make the smallest supported change.
Evaluate packing, algorithms, caching and bounded work before choosing a native
kernel or engine patch; account for conversion, synchronization, memory and
packaging costs. Reuse the existing implementation where it already solves the
problem. Record the intended difference between baseline and candidate sources.

## Compare and deliver

Keep unaffected conditions matched and rerun the same scenario. Each trace must
be compatible with its tested revision; regenerate incompatible inputs through
supported producers rather than bypassing identity checks. If solver or terrain
changes prevent an equivalent workload, disclose that comparison limit.

Read the actual per-run results, logs and source/runtime receipts. Reject
unfocused, minimized, source-drifting or incomplete trials and invalid GPU query
samples. Preserve rejected evidence with its reason and choose a fresh label for
replacement. Report individual runs and medians of run statistics; do not pool
percentiles. Separate rendered and generated frames, CPU and GPU scopes, and
allocation telemetry from physical VRAM occupancy. Repeat only to resolve changed
code, failed trials, noise or a remaining question.

For a repeated rendering baseline, use the maintained
[receipt audit](../../../docs/VALIDATION.md#rendering-baseline-receipt-audit)
on an explicit manifest after the guarded measurements. Preserve invalid attempts,
keep profiles separate, and inspect the identity-matched return-control range.
The table does not certify route coverage, frozen binary integrity, physical VRAM
occupancy or an optimization gain. Follow the predeclared finite drift budget.
Enabled grass may have zero population on a naturally bare-snow route; feature-cost
comparisons still require independently qualified nonzero on-arm coverage.

For five-process unchanged forest controls, follow
[dense-forest A/A controls](../../../docs/VALIDATION.md#dense-forest-aa-controls):
retain the first route traversal separately and accept only the three warmed
repetitions. Check both raw p50 and run-mean spread definitions. The existing
background CPU logger is quantized; do not use it as precise scheduling or
zero-activity evidence. A separately recorded ETW diagnostic requires verified
decoder coverage and cannot by itself explain every unrecorded control.

Use [validation](../alpine-validation/SKILL.md) for affected regression checks and
rendered inspection. Deliver the measured bottleneck, actual change, comparable
before/after values and units, evidence paths, visual/behavior checks and remaining
uncertainty. Distinguish a sampled scenario or microbenchmark from whole-route
performance and human acceptance; retain useful negative or inconclusive results.

Follow [skill maintenance](../../../docs/DEVELOPMENT.md#agent-skill-maintenance)
when benchmark contracts, trace identities, runtime selection, profiling or policy
assumptions change.

## Internal development identity

Follow [development versioning](../../../docs/DEVELOPMENT.md#internal-development-versions)
for each committed milestone, including documentation/backlog authoring. Use
`python scripts/versioning.py identity --json` to identify the current checkout;
keep Dev labels separate from compatibility and evidence source/runtime hashes.
Reserve a unique note and all owned/read inputs, capture hashes before final
verification, record actual checks, and run the scoped note check before commit.
Report the final Dev ID after push. Preserve unrelated dirty inputs; do not refresh
evidence hashes without repeating affected checks. Recorded case identity and
current rerun identity are different observations. A version label is neither
performance evidence nor human/controller acceptance.

For startup/loading responsiveness, follow
[startup timing](../../../docs/VALIDATION.md#startup-evidence). Exclude capture
readbacks and unit preambles, report engine/entry/reveal/menu timings separately,
and keep compact readiness measurements separate from production mountain cost.

For cosmetic gravel, follow [gravel checks](../../../docs/VALIDATION.md#cosmetic-gravel-checks).
Select `-Map gravel`; isolate `-Gravel off|dense|sparse|all` while keeping grass
and physical minerals unchanged. Frozen local and Standard comparisons have
separate scopes; reject measured cache misses and underground review cameras.
