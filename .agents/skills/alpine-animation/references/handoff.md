# Handoff and critique formats

Use these as concise working records under the new revision. Fill only observed
facts. Do not duplicate a whole conversation or carry forward obsolete commands.

## Revision handoff

```markdown
# Animation revision: NAME

Intent: action, phases, user's concrete visible correction.
Status: implemented / rejected candidate / needs correction / awaiting review.
Acceptance: author review status; independent review status; exact user acceptance if given.

Live source changes: owning files/functions and why.
Before evidence: path + evidence ID, engine/hash, source snapshot.
After evidence: path + evidence ID, engine/hash, source snapshot.
Reproduction: exact commands and scenario inputs; required local assets/runtime.
Selected phases: frame IDs + ticks + physical events; selection reasons file.

Observed improvement: before/after visible result and relevant measurements.
Worst remaining issue: action/phase/view/bone or equipment, with evidence link.
Rejected approach: attempted cause, observed failure, why abandoned.

Mechanical validation: suite, result, log, scope/coverage, source identity.
Rendered validation: views, chronological playback, frame/pixel counts, observed issues.
Review/grading: reviewer and evidence-bound records; missing/unjudgeable entries.
Limitations: unsupported actions, missing views, geometry approximations, user playtest pending.
Next useful action: smallest remaining uncertainty and evidence that would resolve it.
Durable lesson: relevant maintained doc updated (if there is a new lesson).
```

## Critic brief

Give a critic the actual final evidence, current user constraints, action/phase
map, camera metadata and the following request. Keep before/after labels neutral
enough to avoid suggesting that the newer version must win.

> Inspect overall motion and every judgeable bone/chain for each requested action
> and phase. Identify the worst visible defects first. Assess final anatomy,
> connected wrists/grips, full equipment silhouette, clothing clearance and
> transitions. Distinguish pose errors from fixed mesh features or occlusion.
> For each score cite a frame/view and describe a concrete correction if needed.
> Do not infer visual quality from mechanical pass counts. State confidence and
> what the supplied evidence cannot establish. Retain the user's requested score
> thresholds without adjusting scores to satisfy them.

Existing feedback record shape (use the package's own evidence ID):

```json
{
  "version": 1,
  "evidenceId": "ACTUAL_PACKAGE_EVIDENCE_ID",
  "reviewer": "ACTUAL_REVIEWER",
  "updatedAt": "ACTUAL_UTC_TIMESTAMP",
  "records": {
    "tuck_01.overall": {"status": "unrated", "score": null, "comment": ""},
    "tuck_01.right_hand": {"status": "unrated", "score": null, "comment": ""}
  }
}
```

Populate all items required by that review package; the two entries above only
illustrate the format. Use `scored` with a numeric score, `unrated` with null, or
`unjudgeable` with null and a reason. Never convert missing feedback to zero or a
passing grade. A new evidence ID needs a new review; old critiques can inform it
but old scores do not automatically transfer.

For the downhill target, report whether every requested phase's overall is ≥8.0
and every judgeable bone is ≥6.5, along with all missing/excluded items. Averages
cannot hide a subthreshold hand. If self-reviewed only, label that clearly. If the
user says “better, but…”, record the improvement and remaining request; do not
mark accepted. R4's final user acceptance remains pending in this case study.
