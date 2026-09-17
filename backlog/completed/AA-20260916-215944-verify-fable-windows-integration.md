---
id: "AA-20260916-215944-verify-fable-windows-integration"
title: "Verify the delivered Fable changes on Windows"
status: done
priority: P1
depends_on: []
created: "2026-09-16T21:59:44Z"
updated: "2026-09-17T03:00:00Z"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
---

# Verify the delivered Fable changes on Windows

## Outcome

Close the concrete Windows validation gaps left by Fable's Mac delivery through
Dev75 without rerunning its entire investigation or claiming an unmeasured FPS gain.

## Current state and evidence

`1022e7ca` through `c53c28e6` delivered HUD/menu caching, exact height queries,
parallel ghost payload loading, wind-trig reuse, explicit foliage cutouts,
global cloud inputs and grass/gravel/texture streaming changes. The committed
notes and [Performance handoff](../../docs/PERFORMANCE_HANDOFF.md#fable-task-overlap-review)
record passed Mac checks, existing failures and pending Windows checks.
Mac shader frame deltas are inside noise; clear-weather views do not establish
cloud-shadow equivalence. A separate worker abort is unresolved, not proven an
engine defect. Do not rerun that Mac stress test from this Windows task.

## Agreed decisions and scope

One integration follow-up owns the overlapping Windows checks from the completed
Fable tasks. Change runtime code only for a reproduced regression; coordinate
with an active owner before touching a new feature. Preserve settings, records,
ordinary input and the 120 Hz solver. Small visual differences and verified
component CPU savings are acceptable under the user's current policy.

## Implementation approach

1. Start with the custom Windows DX12 engine on a compact fixture: compile the
   foliage/global-cloud variants; inspect near/mid/far tree transitions and a
   cloud-shadow view. Reuse current source assets and existing producers.
2. Check settings/menu/crash/ghost selection and grass/gravel cell/texture-tier
   boundaries only where the new code affects behavior. Reuse the existing
   interface suite and targeted maps; do not repeat completed unrelated matrices.
3. If the user is using the machine for gaming, defer native/GPU checks. When
   timing is appropriate, one clean warmed matching dense-route sample is enough;
   only add native pass attribution or a control for an actual unanswered question.

## Acceptance and verification

- [x] Changed shaders compile on DX12; matched rendered checks cover cutouts,
  LOD transitions, cloud shadows and streaming boundaries.
- [x] Required physics/runtime checks for the delivered obstacle/session changes
  and affected interface/archive checks pass, or baseline failures are explicitly
  distinguished from new regressions. No existing failure is relabelled a pass.
- [x] Record Windows CPU/GPU/frame-time/FPS findings separately from Fable's Mac
  figures. Refresh only an incompatible trace through normal runtime validation.
- [x] Close pending Windows items in the handoff and commit/push any actual fixes
  or the bounded acceptance record; keep human/controller review separate.

## Open questions

None

## Completion record

Windows integration qualified on Dev85 production; this milestone changes only
bounded producers and acceptance records. Native DX12 cutout/LOD and cloud-active
views, grass/gravel crossings and atomic macro-tier transitions pass. Five native
UI cases hold the120 cap with31–50 us HUD mean. Capture-free local streaming
records macro swaps below0.153 ms and identifies remaining forest residency
peaks for the existing publication task.367 focused checks pass; unchanged
physics/runtime/archive/selector/race checks reused from Dev80–83.

The current post-Fable108.9339 FPS/9.17988 ms frame/7.51674 ms GPU dense baseline
is reused. No isolated shader depth-pass gain is claimed; another attribution-only
control is waived under current economical policy. No production fix was needed.
Rejected fixture camera/equality attempts are explicitly separated from the
accepted views. [Evidence](../../artifacts/windows_integration_20260917/REVIEW.md)
and [handoff](../../docs/PERFORMANCE_HANDOFF.md#windows-integration-qualification--17-september-2026)
contain scope, actual units, producer commands and limitations. Human/controller
review and the separate Mac worker-abort/collision task remain distinct.
