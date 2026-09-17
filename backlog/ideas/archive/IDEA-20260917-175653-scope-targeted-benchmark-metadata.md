---
id: "IDEA-20260917-175653-scope-targeted-benchmark-metadata"
title: "Use scoped metadata in the local targeted benchmark"
status: accepted
created: "2026-09-17T17:56:53Z"
source_task: "AA-20260911-183812-slope-limited-pole-pushing"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
accepted_task: "AA-20260917-213207-scope-targeted-benchmark-metadata"
---

# Use scoped metadata in the local targeted benchmark

## Why consider this

Bring the local component benchmark under the same economical policy as the
production benchmark, avoiding broad source/asset reads before and after a run.

## Evidence and origin

At Dev102, `tests/targeted_performance.gd::collect_sources` still recursively
hashes scripts, graphics and configuration; its receipt hashes the executable.
`scripts/benchmark_targeted.ps1` compares that hash schema. The production wrapper
already has `scripts/benchmark_metadata.py`; the new pole cost check avoids the
legacy scan through its own bounded producer. This is tooling overhead, not an
observed FPS bottleneck.

## Suggested next step

Share the scoped metadata helper and update the targeted receipt/wrapper contract.
Keep actual settings, map, ordinary-input state, focus and native timing gates.
Test edit detection and synthetic receipts; no fresh FPS baseline is necessary.

## Decisions and risks

Avoid calling metadata byte identity or weakening runtime cache/replay checks.
Group with the completed metadata policy's implementation pattern, without
repeating that original task or silently changing old saved results.

## User decision

The user explicitly requested implementation on 17 September 2026. Completed
as [AA-20260917-213207-scope-targeted-benchmark-metadata](../../completed/AA-20260917-213207-scope-targeted-benchmark-metadata.md), with shared metadata capture and synthetic receipt/edit checks. No FPS baseline
rerun or saved-result conversion is required.
