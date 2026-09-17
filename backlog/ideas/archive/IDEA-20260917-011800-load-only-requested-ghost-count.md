---
id: "IDEA-20260917-011800-load-only-requested-ghost-count"
title: "Load only the requested automatic ghost count"
status: accepted
created: "2026-09-17T01:18:08Z"
source_task: "AA-20260912-132147-reduce-cold-ghost-archive-load"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
accepted_task: "AA-20260917-222200-load-only-requested-ghost-count"
---

# Load only the requested automatic ghost count

## Why consider this

Automatic fastest 1–10 currently bounds the final roster after worker decoding.
Players choosing fewer than ten could avoid reading/decoding unused payloads.
The completed cold-load task accelerated the unchanged default ten-run workload;
selection scheduling is a separate algorithm change.

## Evidence and origin

`CompetitiveRecord.selected()` builds worker jobs for all automatic candidates
before stopping at `automatic_count` while collecting results. The observed
ten-run load now costs 261.554 ms in the retained 150-second stress fixture.
Savings for smaller counts have not been measured.

## Suggested next step

Decode an initial bounded prefix of the requested size, then read only enough
later ranked candidates to replace invalid/missing entries. Keep parallel work
within each batch. Prune unused cached references deliberately. Check count 1,
count 10 and corrupt-prefix fallback with exact ranking/frozen attempt behavior.
Reuse the retained fixture for one before/after count-1 measurement.

## Decisions and risks

Keep all ten available entries and default ten. Manual selection and content
validation stay unchanged. Avoid serializing the default ten-run path or dropping
valid later entries when earlier payloads fail. No new replay schema is needed.

## User decision

Approved for implementation on18September2026. The active goal now covers all
four ideas. [Accepted task](../../completed/AA-20260917-222200-load-only-requested-ghost-count.md) owns implementation,
validation and the final disposition; this proposal remains provenance.
