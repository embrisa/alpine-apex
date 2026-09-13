---
name: alpine-bug-investigation
description: Investigate Alpine Apex bugs from symptoms, recordings or .apexcase files, and verify authorized fixes. Use for reproduction, subsystem attribution and before/after evidence. Routine regression execution and FPS optimization have dedicated skills.
---

# Alpine bug investigation

Start with the observed behavior, expected behavior, trigger and available
evidence. Read [ownership](../../../docs/ARCHITECTURE.md#ownership) and the guide
for the suspected subsystem. Trace input, completed simulation/session state and
presentation separately; a visible pose or camera defect does not by itself
justify changing skiing forces. Keep investigation within the requested scope.

## Reproduce and locate

For a supplied `.apexcase`, read
[recorded bug cases](../../../docs/VALIDATION.md#recorded-bug-cases) and run Inspect
before choosing further work. Commands run from the repository root; replace the
example case path with the supplied file:

```powershell
./scripts/test_case.ps1 -Case 'C:\path\bug.apexcase' -Mode Inspect
```

Read the exported title, observed/expected notes, selected original time range,
endpoint, diagnostic settings and control-event times. Preserve the original.
The wrapper owns its guard and creates fresh evidence; choose a new label/output
for each comparison rather than overwriting a previous result.

- Use `-Mode Capture` when saved poses/camera and the visible symptom matter.
  Inspect the images and actual captured timestamps. Capture uses current
  rendering of recorded state; it does not resimulate a proposed physics fix or
  recover the original renderer's pixels.
- Use `-Mode Rerun` to examine recorded inputs and controls through the current
  solver. Inspect the comparison classification, first relevant divergence,
  contact/impact state, diagnostic interventions and termination against the
  user's notes. An exit code or trajectory difference is not a fix verdict.
- Use `-Mode RerunCapture` when the candidate needs rendered evidence of newly
  simulated poses. It retains recorded camera/weather samples and tuning. Compare
  Capture and RerunCapture outputs with the
  [synchronized comparer](../../../docs/VALIDATION.md#standard-scenarios-and-synchronized-comparison).
  Inspect source/input/coverage warnings and actual image times; fresh Jolt motion
  and nearest captured frames do not establish exact original crash reproduction.

Rerun uses **recorded tuning**. A change to default tuning needs a separate
identified fixture or recording using the new values to establish its effect;
do not silently rewrite the supplied case. Matching-source skiing divergence is
a validation failure; changed-code differences need causal interpretation.
Treat fresh crash motion separately. Reject incompatible cases through the
existing checks; report the specific limitation without inventing missing inputs.

Without a case, use the smallest existing fixture or supported recording that
reproduces the trigger. Check `scripts/scenario.ps1 -List` for retained small-hop,
rough-snow and steady-carve fixtures before adding a new harness. Follow
[bounded descents](../../../docs/VALIDATION.md#bounded-test-descents) for riding
samples. Retain source/runtime, terrain, input, settings and event timing so the
comparison can be repeated. Modified diagnostic scenarios establish only their
stated conditions, not ordinary gameplay or performance acceptance.

## Verify an authorized fix

Locate the earliest state or presentation stage that contradicts the expected
behavior. Check competing explanations with a focused probe before editing;
preserve the pre-change evidence. Use the
[animation skill](../alpine-animation/SKILL.md) when the owning path is final-pose
composition, fitting or equipment attachment.

Change the owning subsystem, then repeat the relevant reproduction with the
intended source/tuning difference identified. Check the triggering event and its
recovery; choose nearby edge cases that could expose a regression. Add a focused
regression when it can meaningfully preserve the behavior, and use
[validation](../alpine-validation/SKILL.md) for required shared suites and rendered
checks. If the symptom cannot be reproduced, report the tested conditions and
remaining uncertainty rather than asserting a cause or a fix.

Deliver the reproduction, supported cause, change if any, and before/after
evidence with its coverage limits. Report recorded visual evidence, current-code
observations and human acceptance separately. Keep unresolved findings and the
original case available for follow-up.

Follow [skill maintenance](../../../docs/DEVELOPMENT.md#agent-skill-maintenance)
when case formats, tuning/control replay, comparison meanings or ownership change.

## Internal development identity

Follow [development versioning](../../../docs/DEVELOPMENT.md#internal-development-versions)
for each committed milestone, including documentation/backlog authoring. Use
`python scripts/versioning.py identity --json` to identify the current checkout;
keep Dev labels separate from compatibility and evidence source/runtime hashes.
Reserve a unique note and all owned/read inputs, capture hashes before final
verification, record actual checks, and run the scoped note check before commit.
Report the final Dev ID after push. Preserve unrelated dirty inputs; do not refresh
evidence hashes without repeating affected checks. Recorded case identity and
current rerun identity are different observations. A version label is neither
performance evidence nor human/controller acceptance.
