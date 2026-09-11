# Windows playtest packaging

`export_presets.cfg` defines **Windows Playtest**, using the current custom
FidelityFX `template_debug` executable. This is the speed-optimized runtime
validated by the FidelityFX work, not a newly built release template. Check
its SHA-256 against `.tools/fidelityfx-runtime.json` before distributing it.

First prepare the target-runtime dependency receipt, then export through the
stock editor. The enabled generation export plugin refreshes dependency hashes
and verifies the selected target executable against this receipt:

```powershell
./scripts/run_snow_check.ps1 -Script scripts/prepare_generation_export.gd -Label generation_export_manifest -TimeLimit 60
New-Item -ItemType Directory -Force builds/AlpineApex-Windows
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--headless','--export-debug','Windows Playtest','builds/AlpineApex-Windows/AlpineApex.exe') -Label windows_playtest_export -TimeoutSeconds 1200
```

The preset retains runtime resources and asset JSON manifests, including
dynamically loaded libraries. The `generation_export` feature uses the refreshed dependency manifest,
so source validation also works when scripts are exported as bytecode. It excludes authoring assets,
test output, tests, documentation, authoring scripts and the MCP addon. The
addon's export plugin removes its runtime autoload during export and restores
the project configuration afterward. Preserve the development addon itself.

Beside the executable and PCK, retain the exported native wind DLL. Copy the
matching `D3D12Core.dll` and unmodified AMD loader, upscaler and frame-generation
DLLs from `.tools/godot-fsr/bin`. Retain the AMD, Godot, Godot third-party and
godot-cpp license notices. See [FidelityFX distribution](FIDELITYFX.md).

Include a player README and version/hash manifest. Use a new clean output
folder per subsequent build so stale files cannot enter the next ZIP. Do not
package a developer's user data, saved races, preferences or shader cache.

## Prebuilt default mountain

The playtest now ships `data/default_mountain_v15.physical` beside the executable.
Prepare it with the selected custom runtime before packaging:

```powershell
$env:ALPINE_BAKE_OUTPUT = 'C:\absolute\new-build\data\default_mountain_v15.physical'
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--headless','--script','scripts/prepare_playtest_bake.gd') -Label playtest_bake -TimeoutSeconds 1200
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--headless','--script','tests/playtest_bake_suite.gd') -Label playtest_bake_checks -TimeoutSeconds 120
```

The preparation script calls `MountainDefinition.generate(849205174,15)` and
checks the existing cache against current sources, engine and terrain identities.
It reuses valid data or pays one necessary bake on the developer's machine.
Do not copy a dated cache into a new build without this validation.

The default v15 loader tries the player's validated local slot first, then the
bundled file in game runtimes. It reads the bundle in place; no install-folder
writes or developer preferences/saves are involved. Both paths use identical
bounded-file, schema, source/engine and payload-checksum validation. An absent
or invalid bundle is ignored and the current generator runs normally. Random
seeds do not use the default bundle. This changes loading, not terrain identity.
Keep the generated dependency manifest and the `generation_export` feature.
The preparation script also validates and copies `default_mountain_v15.scenery`
from a completed High preparation cache. Run the Standard rendered profile first
if it is absent or invalid.

Before sharing, run the packaged executable with an isolated APPDATA folder,
verify first-launch bundled-cache selection, render the menu, drop in and verify
movement. For example (use a new evidence directory for each attempt):

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/test_windows_playtest.ps1','-BuildDirectory','builds/new-build','-EvidenceDirectory','artifacts/playtest-new/first-launch') -Label playtest_first_launch -TimeoutSeconds 900
```

The test records time to menu readiness, cache reconstruction, scene construction,
terrain hashes, physics version, graphics state and downhill movement separately.
Check logs for missing files,
script errors and native-library errors. Test the final ZIP's integrity.
These checks establish local package functionality, not performance or input
feel on a friend's PC. This runtime requires a Windows x86-64 DX12-capable PC.

### V15 validation (2026-09-10)

`builds/AlpineApex-v15-validation/` contains the validated custom runtime,
required native dependencies/licenses and both default Standard caches. Its
`validation_manifest.json` records file hashes, versions and test results. This
is a local validation folder; no archive or public release was created.

The export refreshed and validated the dependency manifest and audited 163
current scripts across 6,896 PCK entries, with development content excluded.
Six physical-bundle acceptance/rejection checks passed. The final isolated
APPDATA launch selected the bundled physical cache and reused bundled scenery,
with both fingerprints matching the tested Standard mountain. It also verifies
that the creation estimate recognizes the Standard bundles and rejects those
hints for Custom settings.

The functional 1280x720 test measured 69.512 s to readiness, 2.610 s internal
physical reconstruction and 39.821 s scene construction. Readiness includes
rider/interface resource loading; the harness performs a separate bundle
preflight before that timer. FSR 4.1.1 and native wind were available; the skier
moved 13.14 m. Standard/Custom controls, estimates and scrolling were inspected,
and the logs had no script/native errors. Tests did not write preferences or
race records. Evidence: `artifacts/generation_v15_export_smoke_final/` and
`artifacts/guarded/v15_final_export*`.

These export checks are distinct from the three matched 4K High loading runs in
[GENERATION_V15.md](GENERATION_V15.md). Forest FPS optimization/target compliance
is deferred at the user's request; user skiing acceptance remains a playtest.

### Historical v14 validation (2026-09-10)

The model-27 package passed eight cache acceptance/rejection checks and a
fresh-APPDATA rendered launch with `cache_source=bundled`. The 78,323,204-byte
bundle reconstructed the mountain in 10.42 s; scene construction took 109.28 s;
menu readiness was 152.48 s after the test's identity preflight. Whole-process
guard time was about 168 s including preflight, captures and a short ski run.
Terrain hashes matched the preparation run and the skier moved 13.72 m.
FSR 4.1.1 and native audio were available; the runtime log contained no errors.
The PCK audit verified 146 current script sources and excluded development and
previous-build content. Menu and skiing captures were inspected at 1280x720.

The earlier 2026-09-09 empty-profile package test took about 668 s including its
short ski run. This is a practical historical comparison, not a matched hardware
benchmark: game updates and machine state differ. The current test explicitly
proves bundled-cache selection without a local mountain cache. Neither result
establishes performance on a friend's PC. The harness validates the bundle before
timing menu readiness, so its whole-process time includes that extra read.

V15 adds separate preparation caching and packed generation; see
[GENERATION_V15.md](GENERATION_V15.md) for current validation. The measurements
in this historical subsection describe the preceding v14 package.
Current evidence is under `artifacts/playtest_20260910/first-launch` and
`artifacts/guarded/playtest_*_20260910`.

The 2026-09-09 build and ZIP are in ignored `builds/`; package-audit and rendered
smoke-test evidence are in ignored `artifacts/windows_playtest/` and
`artifacts/guarded/windows_playtest_*`. Re-run validation for subsequent exports.

### Friend playtest package (2026-09-11)

`builds/AlpineApex-Playtest-2026-09-11-Windows.zip` packages a fresh export of
physics model 28 / default v15 Standard using the hash-verified custom runtime.
The matching folder contains the executable, PCK, native dependencies, licenses,
both validated default caches, player instructions and `BUILD.json` file hashes.

The PCK audit checked 162 current script hashes across 6,897 entries and excluded
development content. All six bundled-bake checks passed. The isolated-profile
1280x720 rendered smoke test selected the physical bundle and reused scenery,
reaching readiness in 106.691 s (3.096 s physical read, 54.102 s scene build).
It verified 39.69 m of downhill movement, FSR 4.1.1 and native wind, with no
script/native errors. Menu and skiing captures were inspected. These are local
package-functionality checks, not a full-descent performance benchmark or
controller/hardware acceptance on the recipient's PC.

Evidence: `artifacts/friend_20260911/` and
`artifacts/guarded/friend_20260911_*`.

The final ZIP passed a complete 7-Zip integrity test: 16 files, 9,299,298,242
compressed bytes (9.30 GB), 11,137,600,638 uncompressed bytes (11.14 GB).
SHA-256: `9cb7de874ff1602367052be58c2005d74e84e6792e7d404986eb6f052d383a67`.
A matching `.zip.sha256` sidecar is available beside the archive.
