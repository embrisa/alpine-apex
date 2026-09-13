---
name: alpine-validation
description: Select, run and interpret Alpine Apex checks for a code change or acceptance review. Use for regression planning, guarded test execution, bounded descents and evidence assessment. Performance experiments and reported-bug diagnosis have dedicated skills; documentation-only changes need only relevant static checks.
---

# Alpine validation

Run commands from the repository root. Read the affected change and
[check selection](../../../docs/VALIDATION.md#check-selection), then only the
relevant domain guide. Use [execution](../../../docs/VALIDATION.md#execution)
for wrapper behavior and [current identity](../../../docs/ARCHITECTURE.md#current-identity)
for source/runtime contracts. Identify the behavior being verified before choosing
tests; a profile is a focused selection, not universal acceptance.

## Select and run

1. Map owned changes and their read dependencies to affected behavior. Include
   required physics/runtime checks for physics, input or session edits. Add the
   relevant rendered inspection for camera, rendering or effects; use the
   [animation skill](../alpine-animation/SKILL.md) for final-pose review.
2. Inspect existing suites and fixtures before adding a harness. Run focused
   checks while iterating and the required complete suites once the change is
   stable. Reuse passing evidence only while its tested inputs remain unchanged;
   repeat for new changes, failures or a specific unresolved concern.
3. Resolve the actual engine through the repository wrapper. Inspect preserved
   dirty read inputs and identify the bytes used; unrelated edits do not require
   cleanup. Recheck affected source for drift before claiming acceptance.
4. Use the existing batch runner or an owning wrapper under the workload guard.
   Use `Shared` for isolated functional checks, `FpsCritical` for comparative
   timing and `Exclusive` for imports/builds/shared cache mutations. Compatible
   shared runs may overlap; reserve common outputs and wait for conflicting leases.
   Never nest guards or interrupt another owner's workload. Choose fresh
   task-specific output directories so results cannot be confused with old runs.

The batch runner supports a read-only plan before taking the guard:

```powershell
./scripts/test_pc_environment.ps1 -Profile input -PlanOnly
```

Select either `-Profile` or `-Suites` and use `-OutputDirectory` for the actual
batch. Read the live runner and execution guide for supported selections and
PowerShell argument handling. Do not copy a full suite list from an old report.
For missing/incompatible mountain fixtures, follow the preparation route in the
execution guide; cold generation and warm-cache checks establish different things.

## Collect only the needed evidence

For riding data, follow [bounded descents](../../../docs/VALIDATION.md#bounded-test-descents):
state the question, event, measured window and clean stop condition; separate
setup/warmup from riding. A guard timeout is a failure backstop, not a successful
sample boundary. Required complete suites retain their full coverage.

For small hops, uneven snow or sustained carving, discover the existing
[standard scenarios](../../../docs/VALIDATION.md#standard-scenarios-and-synchronized-comparison)
with `scripts/scenario.ps1 -List`. Use the common manifest/telemetry and synchronized
comparison page; preserve stimulus, source/tuning identities and coverage limits.
Nearest captured images do not necessarily represent the selected exact tick.

Use [bug investigation](../alpine-bug-investigation/SKILL.md) for a reported defect
or `.apexcase`, and [performance](../alpine-performance/SKILL.md) for comparative
timing. Headless stage duration does not establish rendered FPS. Keep test
preferences and records isolated as specified by the selected producer.

Read `run.json`, `results.json`, relevant logs and emitted captures. Confirm the
expected suites actually ran; `not_run`, engine errors, incomplete output or a
timeout cannot be reported as a pass. Inspect rendered output when required;
successful capture creation alone does not establish visual quality.

Report the tested source/runtime, commands and evidence paths, completed checks
and failures, actual scenario coverage and outstanding acceptance. Distinguish
automated, rendered, performance and human/controller/listening results. Name
the specific missing fixture, conflict or failure when a check cannot complete.

Follow [skill maintenance](../../../docs/DEVELOPMENT.md#agent-skill-maintenance)
when runner behavior, fixtures, check selection or evidence meanings change.
