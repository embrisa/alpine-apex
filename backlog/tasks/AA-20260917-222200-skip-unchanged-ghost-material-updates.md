---
id: "AA-20260917-222200-skip-unchanged-ghost-material-updates"
title: "Skip unchanged ghost material parameters"
status: in_progress
priority: P2
depends_on: []
created: "2026-09-17T22:22:33Z"
updated: "2026-09-17T22:22:33Z"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
---

# Skip unchanged ghost material parameters

## Outcome

Reduce redundant renderer parameter submissions without changing ghost appearance.

## Current state and evidence

ghost_assets.gd unconditionally writes tint and opacity to every material each update; benefit is unmeasured.
Origin: [approved idea](../ideas/archive/IDEA-20260917-013000-skip-unchanged-ghost-material-updates.md).

## Agreed decisions and scope

The user explicitly approved proceeding with all four ideas on18September and
updated the active goal to finish them. The primary agent owns implementation and review. The user revoked Terra use;
do not delegate these tasks to Terra.

Preserve exact tint and clamped opacity, fade curve, ghost isolation, pause/resume and replay behavior. No quantization.

## Implementation approach

Cache last submitted values, write only changed parameters, and initialize new materials from both current values.

## Acceptance and verification

- [ ] Verify fade boundary, palette, material creation and lifecycle. Inspect native overlap/palette views. Measure CPU using a matched saved control or one scoped old/candidate probe. Retain only if measured saving warrants the state.
- [ ] Record actual evidence and limitations, update owning guidance, and push a
  scoped validated milestone. An experiment can finish with a justified rejection.

Human acceptance is a follow-up; no separate approval gate was requested.

## Open questions

None.

## Completion record

Implementation and qualification pending. Initial drafts were set aside after
the user revoked Terra use and rejected the broad ghost-test map. Production
files were restored to Dev108; retained measurements are diagnostic only until
the primary agent independently reviews the candidate and intended workload.
