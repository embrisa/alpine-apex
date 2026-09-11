---
id: "AA-20260911-153901-input-acceptance-evidence"
title: "Refresh skiing and input acceptance evidence"
status: "done"
priority: "P1"
depends_on: ["AA-20260911-153900-baseline-acceptance-index"]
created: "2026-09-11T15:39:00Z"
updated: "2026-09-11T18:59:54Z"
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

- [x] Physics, runtime and controller checks have current results, or a precise blocker/reproducer.
- [x] Covered transitions and disconnect/reset behavior are documented against source.
- [x] Rendered evidence is inspected separately from automated assertions.
- [x] Actual device dead zones, triggers, vibration and skiing feel remain explicitly awaiting the user.
- [x] Commit/push the scoped harness/docs changes and completion record.

A failing required check makes the audit blocked until triaged; do not silently tune gameplay to make it pass. Real-device acceptance is a separate follow-up and not required to finish this evidence task.

## Open questions

None.

## Completion record

Completed 2026-09-11. Evidence/fixture milestone
[`cf5f67a4b6342be86857bcdd184fa63645a41c31`](https://github.com/embrisa/alpine-apex/commit/cf5f67a4b6342be86857bcdd184fa63645a41c31)
was committed and pushed to `origin/main`; the completion record and acceptance
index are the follow-up checkpoint.

Production sources were inspected at
[`29b1767da65f8dc7d75c4937601381a2096ba5fa`](https://github.com/embrisa/alpine-apex/commit/29b1767da65f8dc7d75c4937601381a2096ba5fa):
model 28, replay v5, Godot 4.7.2 custom build `ed1daf0bf`. The existing rendered
fixture needed to observe the new neutral riding-axis gate; it now checks held
input suppression and rearming, reapplies triggers per frame, verifies landing
and test isolation, and supports a separate output directory. No production
solver, mapping, haptics or animation changed.

The [maintained controller audit](../../docs/CONTROLLER_FEEDBACK.md#input-acceptance-audit-on-2026-09-11)
records exact engine hashes, reproduction commands, source-owned lifecycle
behavior and the real-device checklist. Serial guarded checks passed **388/388**:
physics 56, runtime 192, controller input 48, haptics 41 and rider lifecycle 51.
The final native D3D12 Forward+ run passed eight states at 1920x1080 in the
unranked laboratory, with physical haptics and preferences disabled; all eight
images were inspected in order. No guard reported script/engine or driver errors.
Isolated APPDATA kept test saves separate. The pre-render receipt's 605 source
hashes and two executable hashes remained stable through final review.

Raw evidence: `artifacts/input_acceptance_20260911/audit.json`, source receipts
and `visual/`; guard receipts/logs: `artifacts/guarded/input_acceptance_*_20260911/`.
The first native run passed but its output argument was truncated by the launch
wrapper; those outputs were preserved, and the project-relative output argument
was verified by a successful rerun. The maintained report distinguishes this
launch issue from gameplay results and retains the historical evidence sections.

Visual follow-up: [investigate differing tuck postures](../ideas/IDEA-20260911-185650-tuck-presentation-consistency.md).
Initial and resumed tuck look different at similar solver tuck values; the
cause is unproven and no pose-quality acceptance is claimed. The idea is only
proposed for user review. It does not block this input evidence task.

Markdown links/anchors, `./scripts/backlog.ps1 validate`, and `git diff --check`
passed. Physical dead zones, trigger travel, disconnect/reconnect behavior,
vibration comfort, skiing feel and current full-mountain coverage remain open.
No performance measurement or human acceptance was claimed; the
[player/controller task](AA-20260911-153906-player-and-controller-acceptance.md)
remains blocked for actual user feedback.
