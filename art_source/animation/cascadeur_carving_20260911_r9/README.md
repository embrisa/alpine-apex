# R9 deeper carving trial

See [implementation and measurements](../../../docs/presentation/CASCADEUR_DEEP_CARVING_R9.md).
Final capture identity: `cascadeur-20260911-r9-02-{before,after}`; R8/R9 contact
profiles on model 28 with R7 hands. Do not overwrite or regenerate into sealed
revisions. The user's requested target was about 17 cm at deepest carve.

- `analyze.py` checks final fitted poses and matched input times.
- `prepare_media.py` uses maintained video encoding and makes chronological
  front contact sheets; leg crops omit upper-body/pole clearance.
- `build_review.py` creates the R9 landing page using maintained playback controls.
- `finalize_evidence.py` records receipts, source drift and author observations,
  then seals the final evidence. Integrity is separate from visual acceptance.
- `attempt01_*.json` retain the first, slightly shallower calibration.

Run expensive checks serially through `scripts/run_guarded.ps1`; use the existing
user-authorized `-AllowConcurrent` only for isolated functional work, never for
performance claims. Entry recipes are `tests/cascadeur_r9_playtest/run_checks.ps1`
and `run_render.ps1`. The full two-variant clothing audit needs more than the
initial 120-second limit; the completed rerun uses 600 seconds. Both reports
remain useful even if the audit exits nonzero for a shared clothing defect.

`scripts/launchers/Play Cascadeur Deep Carving.cmd` is the user launcher. F9 compares R9 pressure
support with current contacts without pressure sinking, while the browser pair
compares R8 with R9. This pass authors no new Cascadeur source animation.
