---
id: "IDEA-20260917-090000-share-far-tree-material-submissions"
title: "Share material submissions across distant tree variants"
status: proposed
created: "2026-09-17T09:00:00Z"
source_task: "AA-20260914-094136-render-distant-forest-stands"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
accepted_task: null
---

# Share material submissions across distant tree variants

## Why consider this

Reduce far-tree CPU submission work while retaining the actual individual cards,
their tree anchors, depth and eight-view silhouettes. This is an independent
batch/material experiment, not delivery of a grouped stand representation.

## Evidence and origin

Dev 91 dense-route diagnostic: disabling far cards removed about 265 mean draws
and 0.355 ms viewport render CPU, alongside 0.442 ms GPU. The whole forest has 3992
resident far batches split by 384 m cell and 30 assets. Each mesh is already 4
vertices / 6 indices/one surface. Not all resident batches are visible. These net
whole-scene changes do not prove the saving available to material consolidation.
Evidence: `artifacts/far_stands_20260917/attribution.json`.

## Suggested next step

Inspect actual atlas formats, sizes, canopy masks and material differences.
Prototype one immutable mixed-species far cell using a shared texture array and
per-card anchor/variant data. Preserve per-tree billboard orientation, grading,
LOD/residency/reach, canopy aid, lighting and depth; avoid per-frame traversal or
MultiMesh publication. Measure named render CPU and GPU cost before expanding.
Keep original imports and UIDs unchanged; derive only the needed resources.

## Decisions and risks

Texture array unification can inflate memory or reduce texture quality; added
attributes/texture indirection can erase submission savings. Retain conservative
culling granularity and stable FSR motion data. No source-triangle or draw-count
improvement alone is acceptance, and no measured benefit is claimed yet.

## User decision

Current goal authorizes ideas after the tasks/blocked phase. Keep this proposal
for that phase; no implementation or new task dispatch in this milestone.
