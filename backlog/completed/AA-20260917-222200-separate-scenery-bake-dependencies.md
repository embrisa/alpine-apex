---
id: "AA-20260917-222200-separate-scenery-bake-dependencies"
title: "Separate scenery bake inputs from render-only updates"
status: done
priority: P2
depends_on: []
created: "2026-09-17T22:22:33Z"
updated: "2026-09-17T22:22:33Z"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
---

# Separate scenery bake inputs from render-only updates

## Outcome

Keep reusable CPU scenery preparation after a narrowly separable render-only edit.

## Current state and evidence

Scenery bake identity now excludes the two pure foliage-sight display consumers. Full export identity still includes them. All other source/asset/import dependencies remain covered.
Origin: [approved idea](../ideas/archive/IDEA-20260917-082200-separate-scenery-bake-dependencies.md).

## Agreed decisions and scope

The user explicitly approved proceeding with all four ideas on18September and
updated the active goal to finish them. The primary agent owns implementation and review. The user revoked Terra use;
do not delegate these tasks to Terra.

Keep physical generation, serialized sections, asset/import/bounds identities, export integrity and cancellation/publication ownership. Start with the foliage-sight pair only.

## Implementation approach

Audit actual dependency and export paths, then separate the two pure consumers from bake identity while retaining packaged integrity coverage. Avoid unnecessary format churn.

## Acceptance and verification

- [x] Prove render-only changes preserve the cache key/read; real placement, assets, terrain, bounds, bake/schema changes reject stale data. Check compact cache integrity/export paths and bounded warm reuse. No steady-state FPS claim.
- [x] Record actual evidence and limitations, update owning guidance, and push a
  scoped validated milestone. An experiment can finish with a justified rejection.

Human acceptance is a follow-up; no separate approval gate was requested.

## Open questions

None.

## Completion record

Implemented and qualified by the primary agent. Actual temporary display-file
edits preserved the runtime cache key and reused a 6,335-byte packed-array archive
without rewriting. Both files and timestamps were restored. 612 checks passed:
588 retained input paths, scalar keys, cancellation, invalid data and validated
export-map projection. No full mountain or exported game was launched. No FPS
or full-mountain startup-time gain is claimed. Physical generation and archive
schemas remain unchanged; adopting the new key refreshes scenery once.
See `artifacts/scenery_dependency_root_20260918/REVIEW.md` and integration receipts.
