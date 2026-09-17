---
id: "AA-20260913-141128-reduce-forest-publication-and-collision-bursts"
title: "Reduce collision preparation spikes and remaining scenery publication bursts"
status: done
priority: P1
depends_on: []
created: "2026-09-13T14:11:28Z"
updated: "2026-09-17T03:21:57Z"
source_thread: "01a09aec-9f0a-71a3-b543-b8b9765e660d"
---

# Reduce collision preparation spikes and remaining scenery publication bursts

## Outcome

Reduce the individual operations that cause visible frame stalls during skiing,
while keeping required collision coverage and forest/scenery continuity.

## Current state and evidence

Dev60 reduced forest batch publication setup. Dev75 / `c53c28e6` now packs gravel
on workers, budgets grass publication and retires batches incrementally. Fable's
Mac observations put grass streaming p99 near 0.95 to 0.47 ms and macro texture
swap work at 11.9 to 0.12 ms. Do not reimplement these delivered paths.
Fable still reports 44–46 ms frame maxima and a roughly 36 ms terrain collision
cook; correlate the actual event with a slow frame before treating that as causal.
The earlier rejected forest/cook experiments remain in the record below.

Two Mac worker failures are recorded (grass-thread signal11 and later SIGABRT).
The stress test did not reproduce the first. Root cause is unproven; matching
an upstream symptom does not establish an engine bug. Preserve and inspect the
Mac crash log before changing concurrency. No additional broad stress loop is
required merely because a log is unavailable on Windows.

## Agreed decisions and scope

Own `crash_collision.gd`, the relevant terrain/collision preparation boundary and
only the scenery publication/lifetime paths implicated by current evidence.
Keep the 120 Hz solver and 4 m terrain authority. The user permits small physics
tradeoffs for measured benefit; document any such change, update compatibility
when required and run physics/runtime checks. Never leave the rider without
required crash collision or move scene-tree work onto workers.

## Implementation approach

1. Reuse current traces and scope/event records. Identify the longest indivisible
   cook/upload and distinguish cold preparation from warmed re-entry.
2. Try one smaller/cheaper preparation unit or safe ahead-of-need preparation.
   A smaller queue budget cannot preempt one native cook; do not repeat that
   rejected scheduler candidate unchanged.
3. If investigating a worker abort, start with its exact log and object lifetime;
   reproduce in a bounded fixture before claiming a thread-safety fix.

## Acceptance and verification

- [x] One targeted event comparison reduces the identified CPU/stall cost; record
  frame tails separately and retain verified component gains under user policy.
- [x] Required collision coverage, fast travel, return, cancellation and teardown
  pass focused checks; inspect rendered scenery if publication changes.
- [x] Reuse saved matching baselines; one warmed candidate, no manual hash audits
  or repeated baseline matrices. Run physics/runtime when their owners change.
- [x] Commit/push the result and update World/Rendering/Performance handoff as needed.

Human/controller feel and sustained whole-route target remain separate follow-ups.

## Open questions

None

## Completion record

Completed the targeted indivisible-cook candidate on Windows. Interior square
terrain chunks now use the shared height grid; clipped edges keep triangles.
Mean build+attach CPU8.0015 ->2.1262 ms across six Standard chunks (73.43%);
max9.417 ->2.171 ms. Tiny Jolt contact differences (<0.5 mm) are within the
user-authorized physics tradeoff; solver/terrain authority and replay formats
remain unchanged. This is a per-new-chunk saving, not an every-frame saving.

Final focused grid suite7,202, streaming28, physics56/runtime192 pass. Full-grid
coverage, clipped holes, travel/return/retirement, existing cancellation and
teardown contracts pass. Native compact crash stays on snow without fall-through.
Same-process warmed original: 101.61 FPS, 9.841 ms frame, 7.791 ms GPU, p95/p99 13.385/15.328 ms; heightfield: 102.50 FPS, 9.756 ms frame, 7.777 ms GPU, p95/p99 12.917/15.209 ms.
The standalone candidate101.06 FPS was slower than saved108.93 FPS and triggered
that bounded comparison. No dependable whole-route FPS improvement is claimed;
retain the verified preparation gain under current user policy.

Current Mac abort logs are unavailable; no worker failure fix is claimed.
The earlier4.229 ms forest-residency peak is separate residual attribution,
not a reason to repeat rejected scheduling experiments. Human crash/controller
feel and sustained whole-route targets remain separate. Compact evidence:
`artifacts/collision_heightfield_20260917/REVIEW.md`; development note
`changes/3e20b6c83f034fff85c6392d3f71120e.json` identifies the delivered commit.

## Earlier investigation record

Current milestone: pending the 2026-09-14 investigation direction above.
Status is ready for later dispatch after the baseline dependency completes.
Record new evidence, actual validation, remaining acceptance and Dev/commit/push
here. No runtime optimization or new measurement was delivered by this authoring
revision. Earlier status transitions below are dated history, not current dispatch
instructions. Keep the rejected experiments and their provenance intact.

### Prior investigation history (retained)

Investigated manually on 2026-09-13 from Dev 16 (`3a2d2dd2fc6a801fb331a40957f36a2e3e056411`). **Blocked: no production candidate met the required frame-time and control acceptance.** All experimental production, test and guide edits were restored to their exact original bytes; no runtime fix is retained. The [measurement report](../../artifacts/forest_bursts/REPORT.md) retains individual runs, source/runtime audits, event chronology, submission/memory/startup costs and rejected variants.

Tested hidden per-batch forest staging, conservative immediate-detail coverage,
cheaper packed tree queries/direct cylinder attachment, and optional terrain
collision lookahead. Also isolated the tree change with original forest and
terrain paths. Tree refresh CPU cost fell from roughly 6.1 to 3.2 ms per event;
the 16-position diagnostic retained 1,895 attachments while reducing refresh
work from about 87 to 47 ms. Those CPU results are promising attribution, not
sufficient production FPS acceptance.

The combined forest comparison appeared to improve median FPS/p95/p99 from
80.709 / 17.421 / 24.839 to 83.382 / 16.504 / 21.589. Its rock control did not
hold: 89.061 original FPS versus 87.261 candidate and 85.367 on confirmation.
Final original-code controls exposed session drift (forest 76.327 FPS; rocks
86.108 FPS), so these differences do not establish a code-caused regression or
an accepted gain. Against that closing control, the tree-only candidate had
77.434 FPS with worse forest p99 (25.734 versus 24.984 ms), and 81.226 rock FPS.
No candidate established the required repeatable p95/p99 gain and stable controls.

Chronology separates the costs: required forest collision frames above 25 ms
fell from 8/6/7 to 2/1/2, but terrain lookahead added 5/1/2 separate slow frames.
A single cold terrain cook still reached 12.067 ms in forest and 14.473 ms in
rock confirmation. Smaller forest batches reduced the publication unit but
increased total publication overhead and added about 2.1 seconds to cold forest
submission. A 750 microsecond optional scheduler cannot bound a native cook.

The rejected combined candidate passed 694 headless checks across streaming
collision (42), geology collision (16), physics (56), runtime (192), density LOD
(348), and density spatial (40), plus 3,495 native forest preparation checks.
Lifecycle fixtures covered required collision, cancellation, re-entry, reverse
and discontinuous travel, quality changes and teardown. Separate 4K stills and
sampled forward/reverse views showed no added gaps; both 256-step scripted
sequences recorded zero missing required-detail observations. These checks do
not certify continuous motion, full-route performance or controller/crash feel.

The separate normal 120-cap forest check measured 76.086 FPS, p95 17.307 ms and
p99 25.781 ms; the global target remains unmet. Resume with a stable,
counterbalanced timing environment and a smaller or cheaper largest native
cook/upload operation. Preserve cold versus warmed re-entry distinctions and
rerun the full affected matrix; do not ship the microbenchmark or the best
isolated forest run as proof. Human/controller acceptance remains separate.

No replacement domain contract or skill change is retained because the
implementation was rejected. [Development note](../../changes/7516e9a7be084cc5bc81ca3fef168186.json)
records the validated investigation milestone; its containing commit identifies
delivery. Raw evidence, candidate patches and lifecycle fixtures remain under
`artifacts/forest_bursts/` and `artifacts/pc_environment/forest-bursts-*` for the
unresolved finding. Remove only unneeded task helpers after push, following the
artifact lifecycle; preserve those evidence directories.
