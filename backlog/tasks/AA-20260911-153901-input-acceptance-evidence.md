---
id: "AA-20260911-153901-input-acceptance-evidence"
title: "Refresh skiing and input acceptance evidence"
status: "ready"
priority: "P1"
depends_on: ["AA-20260911-153900-baseline-acceptance-index"]
created: "2026-09-11T15:39:00Z"
updated: "2026-09-11T15:39:00Z"
source_thread: "01a090fe-2a8c-7fe0-8b5b-fa6446206ea9"
---

# Refresh skiing and input acceptance evidence

## Outcome

Produce current reproducible input/handling checks and a concise controller playtest checklist without claiming hardware or skiing-feel acceptance.

## Current state and evidence

The [roadmap](../../docs/ROADMAP.md) leaves turn initiation, sustained carving, reversals, tuck transitions, jumps, switch skiing, clean landings and real controllers open. [Controller feedback](../../docs/CONTROLLER_FEEDBACK.md) distinguishes automated coverage from human vibration acceptance. Existing tests/controller_input_suite.gd and tests/controller_input_playtest.gd provide production-input fixtures; the rendered fixture disables physical haptic output.

## Agreed decisions and scope

Refresh evidence for existing behavior. No retuning of the solver, mapping or haptics is authorized by this audit. If a defect is found, record a reproducer and a separate idea for user review. Test harness corrections needed to exercise current contracts are permitted; keep them test-only.

## Implementation approach

Inspect live input, controller lifecycle and relevant harnesses. Run the required physics/runtime suites and focused controller suite with the existing guard. Inspect the rendered controller fixture for the covered transitions. Update the maintained controller documentation with current source/engine identity, actual results, coverage limitations and a short real-device checklist.

## Acceptance and verification

- [ ] Physics, runtime and controller checks have current results, or a precise blocker/reproducer.
- [ ] Covered transitions and disconnect/reset behavior are documented against source.
- [ ] Rendered evidence is inspected separately from automated assertions.
- [ ] Actual device dead zones, triggers, vibration and skiing feel remain explicitly awaiting the user.
- [ ] Commit/push the scoped harness/docs changes and completion record.

A failing required check makes the audit blocked until triaged; do not silently tune gameplay to make it pass. Real-device acceptance is a separate follow-up and not required to finish this evidence task.

## Open questions

None.

## Completion record

Imported from the existing roadmap during backlog setup. Pending implementation. Any worker follow-up ideas belong in `backlog/ideas/` for the user's review.
