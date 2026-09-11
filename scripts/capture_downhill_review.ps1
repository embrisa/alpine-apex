param([string]$Revision = '20260909-r2')
$ErrorActionPreference = 'Stop'
# Run this whole sequence through run_guarded.ps1. Frozen final bones are
# rephotographed at all chronological frames, then at the diagnostic selections.
$root = Split-Path $PSScriptRoot -Parent
$relative = "artifacts/pose_review/revisions/$Revision"
$folder = Join-Path $root $relative
if (Test-Path (Join-Path $folder 'capture/manifest.json')) { throw 'Capture already exists; use a new revision.' }
New-Item -ItemType Directory -Path $folder -Force | Out-Null
'{"regular":[20,80,150],"tuck":[50,106,127],"prepare_takeoff":[28,46,65,66]}' | Set-Content (Join-Path $folder 'selection.json')
$engine = (Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot*_console.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
if (-not $engine) { throw 'Godot console executable not found.' }
& $engine --path $root --headless --script tests/pose_reference_capture.gd -- --probe '--scenarios=regular,tuck,prepare_takeoff' "--output=$relative/capture"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $engine --path $root --script tests/pose_reference_render.gd -- "--revision=$relative"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $engine --path $root --script tests/pose_reference_render.gd -- --diagnostic "--revision=$relative"
exit $LASTEXITCODE
