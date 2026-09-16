---
id: "AA-20260913-141128-reduce-pelvis-fitting-cpu-cost"
title: "Reduce repeated pelvis and anatomy fitting CPU cost"
status: done
priority: P1
depends_on: []
created: "2026-09-13T14:11:28Z"
updated: "2026-09-16T21:59:44Z"
source_thread: "01a09aec-9f0a-71a3-b543-b8b9765e660d"
---

# Reduce repeated pelvis and anatomy fitting CPU cost

## Outcome

Delivered cheaper physical hip fitting, presentation pelvis/knee fitting and
native skeletal tracking while retaining the 120 Hz solver and equipment support.

## Current state and evidence

[Performance handoff](../../docs/PERFORMANCE_HANDOFF.md) records the delivered
Windows native hip kernel (0.185 ms/tick saved; 1,800 full states matched),
pelvis/limits and native tracking (250.55 to 34.13 us/tick; 19,800 tracker and
3,787 final pose/equipment comparisons). These overlapping scopes are not additive.
Dev62 / `7e14b309` merged Apple Silicon kernels and immutable body geometry;
the paired Windows solver was 414.65 to 396.46 us/tick with exact compared states.
Its note and handoff distinguish numerical, rendered and human evidence.

## Agreed decisions and scope

The user explicitly accepts verified CPU savings even without a measurable
whole-frame FPS improvement and small visually credible animation differences.
That supersedes this task's original requirement for an independent FPS win.
The native fitting/caching work is complete; do not restart it as a new task.
Remaining ten-ghost playback throughput belongs to
[the ghost task](../tasks/AA-20260912-132147-reduce-ten-ghost-presentation-cost.md).

## Implementation approach

Retain the integrated native kernels, portable script reference and body geometry
cache. Bone-index/pose-writer experiments were independently measured and rejected
in [Fable's completed investigation](AA-20260916-084501-index-skier-pose-by-bone.md).

## Acceptance and verification

- [x] Measured fitting/tracking CPU savings and bounded output comparisons recorded.
- [x] Matched rendered poses and affected regression evidence recorded in the handoff.
- [x] Runtime implementation and platform integration committed and pushed.

Four pre-existing skier-motion/animation assertions remain documented baseline
findings, not passing checks. Pole transitions have their own blocked task.
Human motion/controller acceptance remains a separate follow-up. No checks
were rerun and no new performance result is claimed by this grooming.

## Open questions

None

## Completion record

Closed from delivered main through Dev75, especially the native fitting/tracking
milestones and Dev62 integration. The user's small-gain policy accepts the
verified CPU result; sustained 90–120 FPS remains a separate project objective.
Owning contracts: Development / native skier math and Animation / runtime cost.
