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
`-SkipImport` installs/verifies without importing. Blender/Cascadeur are only
needed for their authoring workflows.

`godotw.ps1` resolves the validated custom runtime for game/test invocations;
editor, import and export use stock Godot. `./godotw.ps1 --editor` opens that
editor; F5 there uses stock rendering. `GODOT_BIN` overrides automatic selection.
The resolver validates the activation receipt against exact executable hashes.
`godotw-fsr.ps1` explicitly selects the custom runtime. The shell `godotw` keeps
the existing stock-engine path on other platforms.

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

## Artifact lifecycle

`artifacts/` is ignored except its guide and `.gdignore`. Suites/review tools
produce logs, captures, frozen comparisons and receipts there. It is not an
asset dependency or a substitute for maintained documentation. Retain useful
source in `art_source/`, runtime assets in `assets/`, fixtures in `tests/fixtures/`.

With Godot/Blender workloads closed, `./scripts/clean_artifacts.ps1 -WhatIf`
previews cleanup; omit `-WhatIf` to remove output. The helper uses the validation
lock, rejects unsafe roots/tracked surprises and unlinks junctions without
traversing their targets. Preserve needed sealed evidence during active reviews.
Missing historical captures require a new known baseline; never invent a receipt.

Validation execution and output interpretation are owned by [Validation](VALIDATION.md).
Do not turn subsystem documentation into a run-by-run changelog.
