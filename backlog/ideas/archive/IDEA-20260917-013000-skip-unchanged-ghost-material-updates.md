---
id: "IDEA-20260917-013000-skip-unchanged-ghost-material-updates"
title: "Skip unchanged ghost material parameters"
status: accepted
created: "2026-09-17T01:35:24Z"
source_task: "AA-20260912-132147-reduce-ten-ghost-presentation-cost"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
accepted_task: "AA-20260917-222200-skip-unchanged-ghost-material-updates"
---

# Skip unchanged ghost material parameters

## Why consider this

Each visible ghost writes tint and opacity to every material each frame. Tint
usually stays constant, and opacity is constant beyond the fade range. Avoiding
redundant script-to-renderer calls may reduce CPU submission work.

## Evidence and origin

`GhostAssets.tint()` unconditionally calls `set_shader_parameter()` for both
values on every owned material. `PersonalBestGhost.update_ghost()` invokes it
each update, including paused updates. This is a source observation; the engine
may already suppress part of the downstream work, so no gain is established.
The current playback task targets repeated pose decoding separately.

## Suggested next step

Remember the last submitted tint and clamped opacity. Update only changed
parameters, ensuring newly created materials receive the current values.
Measure the ten-ghost update cost against a matching saved control and check
appearance changes, near/far fade boundaries, pause/resume and the 15% floor.

## Decisions and risks

Do not quantize opacity, alter colours or change the fade curve. Material
creation/replacement must invalidate or initialize the remembered state correctly.
Only retain the change if its measured CPU saving justifies the extra state.

## User decision

Approved for implementation on18September2026. The active goal now covers all
four ideas. [Accepted task](../../tasks/AA-20260917-222200-skip-unchanged-ghost-material-updates.md) owns implementation,
validation and the final disposition; this proposal remains provenance.
