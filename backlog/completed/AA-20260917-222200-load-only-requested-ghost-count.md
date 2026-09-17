---
id: "AA-20260917-222200-load-only-requested-ghost-count"
title: "Load only the requested automatic ghost count"
status: completed
priority: P2
depends_on: []
created: "2026-09-17T22:22:33Z"
updated: "2026-09-17T22:22:33Z"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
---

# Load only the requested automatic ghost count

## Outcome

Avoid loading unused replay payloads when Automatic requests fewer than ten ghosts.

## Current state and evidence

Previously, automatic selection scheduled all ten candidates before truncating. It now reads the requested prefix and fills only unavailable slots.
Origin: [approved idea](../ideas/archive/IDEA-20260917-011800-load-only-requested-ghost-count.md).

## Agreed decisions and scope

The user explicitly approved proceeding with all four ideas on18September and
updated the active goal to finish them. The primary agent owns implementation and review. The user revoked Terra use;
do not delegate these tasks to Terra.

Keep ranked selection, missing/corrupt fallback, manual selection, immutable attempt rosters, payload validation and default ten-way parallelism.

## Implementation approach

Use deficit-sized ranked batches. Maintain bounded aggregate admission and caller-owned cache publication. Keep valid previous-batch entries while filling replacements.

## Acceptance and verification

- [x] Check count1/count10, missing/corrupt prefix, manual selection and retry/invalidation. Compare one count-one control/candidate with the retained fixture; report loading latency and memory, not FPS.
- [x] Record actual evidence and limitations, update owning guidance, and push a
  scoped validated milestone. An experiment can finish with a justified rejection.

Human acceptance is a follow-up; no separate approval gate was requested.

## Open questions

None.

## Completion record

Implemented and qualified by the primary agent. Count-one initial load fell
from 299.629 to 65.707 ms; retry from 261.206 to 3.697 ms against the saved matching
control. Read/hash lookups fell from ten to one and compressed bytes from
7,797,678 to 788,553 per call. All six regression suites passed, 611 checks.
This is loading responsiveness, not an in-game FPS claim. No rendering changes.
See `artifacts/ghost_count_root_20260918/REVIEW.md` for scope and receipts.
