# Development

## Checkout and engine selection

The private repository is `embrisa/alpine-apex`. Git LFS carries models,
textures, audio, editable art, collision data and the Windows toolchain.
The purchased TreeDesigner authoring library is local-only; exported game
assets are included. Git policy and the LFS spending limit are in [AGENTS](../AGENTS.md).

From a checkout with Git/LFS and PowerShell 7:

```powershell
git lfs pull
./scripts/setup_collaboration.ps1
./godotw.ps1
```

[Setup](../scripts/setup_collaboration.ps1) verifies
[the archive/file hashes](../tools/windows/toolchain.json), extracts the pinned
editor and custom runtime into ignored `.tools/`, then imports assets. First
import can exceed 20 minutes. Repeat setup after pulling a toolchain change;
`-SkipImport` installs/verifies without importing. Blender is only
needed for its authoring workflows.

`godotw.ps1` resolves the validated custom runtime for game/test invocations;
editor, import and export use stock Godot. `./godotw.ps1 --editor` opens that
editor; F5 there uses stock rendering. `GODOT_BIN` overrides automatic selection.
The resolver validates the activation receipt against exact executable hashes.
`godotw-fsr.ps1` explicitly selects the custom runtime. The shell `godotw` keeps
the existing stock-engine path on other platforms.

## Internal development versions

`Dev N` identifies one committed, validated milestone, including documentation
and agent tooling. It is not a public release version. The immutable parent of
Dev 1 is recorded in `config/development_version.json`; N is its first-parent
commit distance. Earlier history stays unnumbered. Keep one milestone and one
new `changes/<uuid>.json` note per commit. Never edit old notes or reset the
baseline; corrections receive a new milestone. No per-commit tags or Git hooks
are installed. Full commit hashes remain the exact committed identities.

`python scripts/versioning.py identity` prints the current Dev ID, Git hash,
modified state/fingerprint and source-owned compatibility identities; add
`--json` for agents. Incomplete/unrelated/shallow Git history gives `Dev unknown`
with a reason, never an estimated number. Fetch complete history to resolve it.
A modified checkout keeps its committed number and adds `+ modified`. Its
fingerprint covers non-ignored working changes and index identities, including
untracked/deleted files. It is an observation, not a validation certificate.

### Milestone workflow

Manual agents and scheduled workers use the same helper. Keep normal ownership,
path-only staging/commits, validation guards and push requirements. Scheduled
workers also reserve their unique note path; compatible agents never edit a
shared counter or changelog. Unrelated dirty/staged files remain untouched.

1. Save an ignored scope JSON with literal repository-relative `write_paths` and
   `read_paths` arrays. Include all files to be committed, UIDs, owning docs and
   meaningful test dependencies; directories expand to their current contents.
2. Scheduled workers first choose a UUID (PowerShell: `[guid]::NewGuid().ToString('N')`),
   reserve `changes/<uuid>.json` through their scope helper, and pass that exact
   path with `note --note changes/<uuid>.json`. Creation is exclusive and refuses
   to overwrite an existing note. Manual callers may omit `--note` to generate
   a new UUID. Create the note, fill `areas`, compatibility decisions/data effects, and the
   intended acceptance boundary. Retain the returned unique path:

   ```powershell
   python scripts/versioning.py note --scope artifacts/my-change/scope.json --summary "Describe resulting behavior" --category Presentation
   ```

3. Run `python scripts/versioning.py capture --note changes/ID.json --metadata-only` immediately
   before final verification. This records scoped file sizes/timestamps and expected
   before/after compatibility values. Then execute the required checks and fill
   `checks` with their actual commands, results and evidence references. Capture
   does not run tests or certify a pass. Re-capturing after code changes requires
   repeating affected checks; do not refresh metadata merely to silence drift.
4. Run `python scripts/versioning.py check --note changes/ID.json`. After staging
   only owned paths, repeat with `--staged`; unrelated staged files are excluded.
   Commit exactly those source paths and the new note, then push. Use
   `python scripts/versioning.py check --commit HEAD` to check delivered scope,
   and `identity` to report the final Dev number and commit.

Notes use categories `Maintenance`, `Presentation`, `Gameplay`, `World`, and
`Data format`; combine them when appropriate. For compatibility-sensitive edits,
record `physics`, `world`, or `data` decisions with `effect` (`preserved` or
`changed`) and a concrete `reason`. Path classification requests a decision; it
does not infer behavioral changes. Changed physics requires a model/tuning/tick
identity change; changed physical generation requires a generator increment.
Declare effects on mountains, races, records, ghosts and caches using
`preserved`, `incompatible`, `regenerate`, or `not_applicable`, each with a reason.
Data-schema changes use their existing source owners. Dev IDs never enter any
save, race, replay, or cache compatibility key.

Check entries have `kind` (`automated`, `rendered`, `performance`, `human`),
`command`, `result`, and `details`. A milestone requires passed verification;
failed or pending required non-human checks block it. `not_required` needs an
explanation. Separately pending human acceptance must be recorded in
`outstanding_acceptance` and must not be a task completion gate. The checker
verifies structure, scope and the recorded verification mode, not the truth of
prose assertions. Metadata mode checks size/time drift before commit and scoped
Git index agreement; delivered checks establish path presence and compatibility,
not content-hash identity. This intentionally skips hash audits under the user's
economical validation policy. The older hash mode remains available only for an
explicit request; omit `--metadata-only` to opt in. Existing runtime identity,
replay/cache keys and export formats are unchanged.

In opt-in hash mode, LFS capture hashes the hydrated working file. Staged checks verify
the canonical SHA-256 v1 pointer's content OID **and byte size** against that
tested file; an unhydrated pointer is not accepted as the working asset.
Historical checks compare the committed pointer's content OID with the note's
tested hash. They do not fetch or certify remote LFS-object availability; the
normal LFS push remains required. Malformed or unsupported pointers do not gain
content-hash equivalence. The format is defined by the
[Git LFS specification](https://github.com/git-lfs/git-lfs/blob/main/docs/spec.md).

The worker's done release checks its scoped commits since acceptance. Record
terminal backlog changes before final note capture/commit when possible. If a
separate administrative commit is needed, give it its own Maintenance note.

### History, runtime and packages

`python scripts/versioning.py history` generates readable Markdown from notes
and their containing commits; `--json` provides structured history and `--output`
saves an ignored report. Missing notes remain conspicuous history gaps. Raw Git
subjects alone never imply validation. Notes are authoritative; generated history
is not a second hand-maintained changelog.

Title/pause menus display the compact identity; **Tools → Copy build details**
uses the existing controller focus flow. There is no in-game notes browser.
The process resolves identity once; restart after changing code. Checkout identity
uses Python 3.10+ and Git (`ALPINE_PYTHON` may select the Python executable).
Exported games use a hashed embedded manifest and need neither tool. Runtime
reports include the actual Godot executable identity, even if it differs from
the expected packaged engine. Do not interpret the manifest checksum as anti-cheat.

The Windows packaging helper validates the committed note by default. To test a
validated, uncommitted milestone use `-MilestoneNote changes/ID.json`. Modified
packages remain explicitly labelled; with no supplied note, local changes are
reported as unverified. Metadata is injected by the existing export plugin;
export through the helper so it can prepare the identity and compare source and
target-engine state before/after export. It writes `build-identity.json`,
`BUILD.json`, and `CHANGES.md` beside the game. Runtime identity and output hashes
serve different purposes. An export with source drift is incomplete and must be
rebuilt. Documentation/evidence-only working changes do not invalidate the export
input fingerprint. Existing generation receipts and engine safeguards still apply.

## Native builds

### FidelityFX

The engine module and patch live in `native/fidelityfx/`; the working engine
checkout and SDK are ignored `.tools/godot-fsr` and `.tools/FidelityFX-SDK`.
The build pins Godot 4.7.2 `ed1daf0bf001b61586d9930840f2f1394092c079` and AMD
FSR SDK 2.3.0 `60f4ea81909200d8542eca14dccb2628b763a9a3`. Recheck these in
the build/install scripts before updating dependencies.

```powershell
./scripts/install_fidelityfx.ps1
./scripts/build_fidelityfx_probe.ps1 -Run
./scripts/build_fidelityfx_engine.ps1
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/test_fidelityfx.ps1') -Label fidelityfx-native -TimeoutSeconds 600
./scripts/activate_fidelityfx.ps1
```

Requires VS 2022 C++, Windows SDK, CMake and Python/SCons. The installer validates
the SDK commit/source state and AMD DLL signatures. Engine preparation rejects
unexpected source layouts and preserves unrelated edits. Activation requires
matching suite/render receipts and signed runtime hashes; rebuilding requires
revalidation/reactivation. Renderer-specific contracts are in [Rendering](RENDERING.md#fidelityfx).

### Wind and SFX

`./scripts/build_wind.ps1 -Test` builds/tests the static-runtime Windows x64 DLL
and copies it into `addons/alpine_wind`. CMake/VS 2022 are required; the script
pins godot-cpp `godot-4.5-stable`, commit
`e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`, under `.tools/wind`.
An engine holding the DLL must release it before replacement; the build does
not close applications. The stream/thread contracts live in [Audio](AUDIO.md).

## Windows packaging

```powershell
./scripts/build_collaboration.ps1
```

The helper owns its validation guard. It prepares the generation dependency
receipt, exports the **Windows Playtest** preset with the stock editor, and
copies runtime DLLs/licenses. Output is a fresh timestamped `builds/` directory;
`-OutputDirectory builds/my-playtest` chooses another empty destination.
`BUILD.json` records hashes. The selected custom executable is the validated,
speed-optimized `template_debug`, not an independently validated release build.

The export plugin refreshes source/asset digests and checks the target executable
against its prepared receipt. Keep `generation_export`, dynamic asset JSON and
native wind resources. Export excludes authoring/reference material, tests, docs,
generated output and MCP tooling; the MCP export hook removes its autoload for
the export and restores development configuration afterward.

Ship the matching `D3D12Core.dll`, unmodified AMD-signed loader/upscaler/frame-
generation DLLs, native wind DLL and AMD/Godot/Godot-third-party/godot-cpp notices.
Include player launch instructions and version/hash metadata. Do not bundle
developer preferences, records, shader caches or purchased source libraries.

### Optional default-mountain bake

An ordinary collaboration build generates its mountain on first launch. To ship
prepared Standard data, first complete a current High rendered preparation, then:

```powershell
$env:ALPINE_BAKE_OUTPUT = 'C:\absolute\new-build\data\default_mountain_v15.physical'
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--headless','--script','scripts/prepare_playtest_bake.gd') -Label playtest-bake -TimeoutSeconds 1200
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--headless','--script','tests/playtest_bake_suite.gd') -Label playtest-bake-check -TimeoutSeconds 120
Remove-Item Env:ALPINE_BAKE_OUTPUT
```

Set the output explicitly; the producer validates current sources, engine and
terrain, and also copies valid High scenery preparation. Missing scenery requires
the rendered preparation, not an old cache copied by hand. Local/bundled/fresh
selection and cache invalidation are in [World](WORLD.md#caches-and-export).

Test the actual packaged executable/PCK with isolated APPDATA:

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/test_windows_playtest.ps1','-BuildDirectory','builds/new-build','-EvidenceDirectory','artifacts/playtest-new/first-launch') -Label playtest-first-launch -TimeoutSeconds 900
```

Verify menu, drop-in/movement, cache selection, missing-file/native errors and
final ZIP integrity. Record actual size/hash. This establishes package operation
on the test PC, not performance/controller feel on another PC.

## Agent skill maintenance

Repository skills in `.agents/skills/` describe workflows; domain guides remain
authoritative for technical facts and policies. The agent changing an underlying
contract also owns reviewing the affected skill and updating it in the same
validated milestone. Review only affected workflows; an implementation edit that
preserves their contracts does not require rewriting skill text.

| Skill | Changes that require review |
|---|---|
| [Validation](../.agents/skills/alpine-validation/SKILL.md) | `scripts/test_pc_environment.ps1`, `scripts/run_guarded.ps1`, `scripts/validation_lease.ps1`, `scripts/scenario.ps1`, scenario catalog/runner/evidence schema, engine selection, test profiles/fixture preparation, result/log semantics, check-selection or bounded-descent policy |
| [Bug investigation](../.agents/skills/alpine-bug-investigation/SKILL.md) | `scripts/test_case.ps1`, `scripts/diagnostics/case_tool.gd`, `scripts/pose_review/compare_scenarios.py`, case/scenario evidence formats, recorded tuning or control replay, comparison/capture semantics, subsystem ownership |
| [Performance](../.agents/skills/alpine-performance/SKILL.md) | `scripts/benchmark_pc.ps1`, trace producers/validators, profiling/result formats, runtime/cache identity, performance targets/method, workload exclusivity or engine strategy |

These are dependency entry points, not an exhaustive file allowlist. Follow
changed callers/contracts and linked guides when a dependency moves or is replaced.
Update affected descriptions, instructions, command examples, links and UI metadata
together. Remove replaced recipes within scope; derive volatile versions, hashes,
settings and suite membership from live producers or owning guides.

For a changed skill, run the installed skill-creator's `scripts/quick_validate.py`
against its directory, check local links/anchors and named source paths, and verify
command options against the current scripts. Exercise a safe plan/dry run when
available; use already-required runtime checks for changed executable behavior.
Review realistic task routing and result interpretation as well as syntax. Record
what was actually verified in the milestone report; static validation alone does
not establish improved agent performance. No engine run is needed for prose-only
changes. If discovered drift is outside the current write scope, report the exact
skill/dependency and coordinate its update while continuing independent work.

## Artifact lifecycle

`artifacts/` is ignored except its guide and `.gdignore`. Suites/review tools
produce logs, captures, frozen comparisons and receipts there. It is not an
asset dependency or a substitute for maintained documentation. Retain useful
source in `art_source/`, runtime assets in `assets/`, fixtures in `tests/fixtures/`.

With Godot/Blender workloads closed, `./scripts/clean_artifacts.ps1 -WhatIf`
previews cleanup; omit `-WhatIf` to remove output. Use `-TargetPath` only with
literal existing repository-relative paths beneath `artifacts/` to narrow a
cleanup, and `-KeepPath` to retain literal existing files or complete subtrees
inside that target. With no target, the root remains the scope. The helper uses
the validation lock, rejects paths outside the artifact root and unlinks junctions
without traversing their targets. Preserve needed sealed evidence during active
reviews. Missing historical captures require a new known baseline; never invent a
receipt.

Validation execution and output interpretation are owned by [Validation](VALIDATION.md).
Do not turn subsystem documentation into a run-by-run changelog.
