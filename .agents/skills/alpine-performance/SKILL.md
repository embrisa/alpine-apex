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

## Attribute and change

Use [benchmark_pc.ps1](../../../scripts/benchmark_pc.ps1) for production frame
measurements; consult the measurement guide for its guarded invocation. Select
an explicit compatible `-InputTrace`, event window, fresh `-Label`, repetitions
and effective settings. Do not rely on its historical default trace path.
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

Use [validation](../alpine-validation/SKILL.md) for affected regression checks and
rendered inspection. Deliver the measured bottleneck, actual change, comparable
before/after values and units, evidence paths, visual/behavior checks and remaining
uncertainty. Distinguish a sampled scenario or microbenchmark from whole-route
performance and human acceptance; retain useful negative or inconclusive results.

Follow [skill maintenance](../../../docs/DEVELOPMENT.md#agent-skill-maintenance)
when benchmark contracts, trace identities, runtime selection, profiling or policy
assumptions change.
