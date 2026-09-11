# Generated validation output

This directory is disposable. Tests and authoring tools write logs, reports,
captures, comparison videos and temporary project copies here. Outputs are
excluded from Godot imports by `.gdignore`.

Keep required source assets in `art_source/`, runtime assets in `assets/`, and
regression fixtures in `tests/fixtures/`. A normal project copy must not depend on a
previous local comparison run.

From the project root, with Godot and Blender closed:

```powershell
./scripts/clean_artifacts.ps1 -WhatIf
./scripts/clean_artifacts.ps1
```

Cleanup deletes all output, including old reports and frozen comparison projects.
It keeps this file, `.gdignore` and the validation lock. It uses the same exclusive
lock as `run_guarded.ps1`, unlinks shared-asset junctions without traversing them,
refuses a linked artifact root or unexpected artifact files,
and leaves `.godot/`, `.tools/`, authoring assets and user saves/caches alone.

Rerun the relevant producer before consuming its output. For example, old v11
geology contract/descent probes need `tests/geology_generation_suite.gd` first.
Historical before/after runners may need a newly prepared baseline; the numeric
regression fixtures remain available without those local copies.

Past artifact paths in implementation notes describe output locations, not files
included with the project. The old local evidence was cleared on 2026-09-09.
See [validation](../docs/VALIDATION.md) for current checks and acceptance limits.
