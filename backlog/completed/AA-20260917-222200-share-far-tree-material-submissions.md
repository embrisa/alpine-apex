---
id: "AA-20260917-222200-share-far-tree-material-submissions"
title: "Share far-tree material submissions"
status: done
priority: P2
depends_on: []
created: "2026-09-17T22:22:33Z"
updated: "2026-09-17T23:29:00Z"
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

- [x] Reject poor visuals before timing. If credible, use capture-free matched render-CPU/GPU/frame timing and memory; expand only on a justified gain. Completed investigation may reject the candidate; do not ship draw-count-only or quality-regressing changes.
- [x] Record actual evidence and limitations, update owning guidance, and push a
  scoped validated milestone. An experiment can finish with a justified rejection.

Human acceptance is a follow-up; no separate approval gate was requested.

## Open questions

None.

## Completion record

Primary-agent frozen prototype completed and qualified. Same 1,686 individual
cards and 54,572 scene primitives; 26 tree batches become two native-format
texture-array batches. Seven paired native 4K views passed visual review;
6,966 assertions cover actual card reconstruction, layout and captures.

Capture-free 15-second local-cell samples: viewport render CPU 0.087980 to
0.063289 ms (0.024692 ms saved); frame mean 2.435376 to 2.376419 ms, or 410.61 to
420.80 FPS. GPU 2.002537 to 1.993071 ms is effectively unchanged. Both qualified
arms have zero unfocused frames/invalid queries. An unfocused first candidate
was rejected; only the candidate was repeated, reusing the valid original.

Decision: retain this working candidate as worthwhile for production integration.
This completes the agreed one-cell evaluation, not a production renderer change
or full-mountain FPS claim. The frozen pilot retains both source textures and
arrays: 85.34 MiB array payload, 96 MiB incremental texture allocation and
26,976 bytes extra instance data. Integration must replace duplicate residency
and qualify merged-bound culling and motion on the actual route before shipping.
Production assets, shaders, imports, UIDs and settings remain unchanged.

Evidence and exact scope: `artifacts/far_material_root_20260918/REVIEW.md`,
`comparison.json`, `visual2/` and `candidate-timing/`. Pilot source and compact
stand fixture are retained; no full project copy or new mountain bake.
