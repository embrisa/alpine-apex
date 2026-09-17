---
id: "AA-20260917-222200-share-far-tree-material-submissions"
title: "Share far-tree material submissions"
status: in_progress
priority: P2
depends_on: []
created: "2026-09-17T22:22:33Z"
updated: "2026-09-17T22:22:33Z"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
---

# Share far-tree material submissions

## Outcome

Evaluate whether a shared-material far cell saves submission time while preserving the existing individual cards.

## Current state and evidence

Far groups partition by384m cell and asset. Cards already use two triangles; draw reduction alone is not acceptance. Prepared source audit is in artifacts/backlog_preparation_20260917/far_materials.md.
Origin: [approved idea](../ideas/archive/IDEA-20260917-090000-share-far-tree-material-submissions.md).

## Agreed decisions and scope

The user explicitly approved proceeding with all four ideas on18September and
updated the active goal to finish them. The primary agent owns implementation and review. The user revoked Terra use;
do not delegate these tasks to Terra.

Frozen reversible experiment first. Preserve anchors, billboard/crown geometry, eight-view textures, depth, grading, LOD/residency, foliage aid, lighting, source assets and settings. No per-frame compaction.

## Implementation approach

Prototype one immutable mixed-species cell with native-size texture arrays and per-instance variant/bounds data. Review the proposed transform mapping before coding. Bound memory and avoid duplicate source-array residency on integration.

## Acceptance and verification

- [ ] Reject poor visuals before timing. If credible, use capture-free matched render-CPU/GPU/frame timing and memory; expand only on a justified gain. Completed investigation may reject the candidate; do not ship draw-count-only or quality-regressing changes.
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
