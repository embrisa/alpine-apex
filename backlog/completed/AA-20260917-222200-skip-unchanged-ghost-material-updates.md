---
id: "AA-20260917-222200-skip-unchanged-ghost-material-updates"
title: "Render solid replay skiers with jacket-only colors"
status: done
priority: P2
depends_on: []
created: "2026-09-17T22:22:33Z"
updated: "2026-09-17T22:22:33Z"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
---

# Render solid replay skiers with jacket-only colors

## Outcome

Render ordinary solid skiers with distinct jacket colors, and avoid redundant jacket parameter updates.

## Current state and evidence

The former renderer tinted and alpha-blended every surface. The user explicitly replaced that design with solid skiers and jacket-only colors on 18 September.
Origin: [approved idea](../ideas/archive/IDEA-20260917-013000-skip-unchanged-ghost-material-updates.md).

## Agreed decisions and scope

The user explicitly approved proceeding with all four ideas on18September and
updated the active goal to finish them. The primary agent owns implementation and review. The user revoked Terra use;
do not delegate these tasks to Terra.

Use opaque materials, recolor only jacket fabric, and preserve normal equipment/trouser appearance. Preserve private material ownership, pause/resume and replay behavior. The user explicitly removed the previous transparency and distance-fade requirement.

## Implementation approach

Keep production shaders on all other surfaces. The clothing shader recolors warm jacket atlas texels and preserves dark trousers. Send the jacket tint only when it changes and initialize late materials from the current color.

## Acceptance and verification

- [x] Verify opaque visibility, palette, unchanged non-jacket materials, creation and lifecycle. Inspect native front/back/close views. Compare unconditional and cached jacket setters in one focused CPU probe.
- [x] Record actual evidence and limitations, update owning guidance, and push a
  scoped validated milestone. An experiment can finish with a justified rejection.

Human acceptance is a follow-up; no separate approval gate was requested.

## Open questions

None.

## Completion record

Implemented by the primary agent. Native perf-slopes views show solid skiers
with jacket-only colors; all functional checks passed. Ghost archive, pose cache
and capture reuse suites passed 5,496 checks. The maintained broader producers
compile; they were not launched. Jacket setter CPU fell from 11.65625 to 6.95667
microseconds per ten-skier steady update versus an equivalent unconditional
setter. This small CPU gain is retained; no whole-frame FPS claim.
Evidence: `artifacts/ghost_material_root_20260918/REVIEW.md` and `jackets/`.
Human judgment of the shown jacket colors remains separate from automated checks.
