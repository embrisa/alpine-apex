param([switch]$Worker,[ValidateSet('checks','visual','controls','timing')][string]$Stage = 'checks',
    [switch]$FullMountain = ($env:ALPINE_FULL_MOUNTAIN -eq '1'),
    [string]$FullMountainReason = $env:ALPINE_FULL_MOUNTAIN_REASON
)
$ErrorActionPreference = 'Stop'
$snowRoot = Split-Path $PSScriptRoot -Parent
if (-not $Worker) {
    $snowDeadline = (Get-Date).AddMinutes(30)
    while ($true) {
        $snowLease = $null
        try { $snowLease = [IO.File]::Open((Join-Path $snowRoot 'artifacts/validation.lock'),'OpenOrCreate','ReadWrite','None') } catch {}
        $snowBusy = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*.exe' -and $_.CommandLine -match '(--script\s|--import)' })
        if ($snowLease) { $snowLease.Dispose(); if (-not $snowBusy.Count) { break } }
        if ((Get-Date) -ge $snowDeadline) { throw 'Snow validation queue exceeded 30 minutes; other workloads left untouched.' }
        Start-Sleep -Seconds 2
    }
    & "$PSScriptRoot/run_guarded.ps1" -FilePath pwsh -Arguments @('-NoProfile','-File',$PSCommandPath,'-Worker','-Stage',$Stage) -Label "soft-snow-$Stage" -TimeoutSeconds 1800 -CollectGpuMemory -FullMountain:$FullMountain -FullMountainReason $FullMountainReason
    exit $LASTEXITCODE
}
if ($Stage -eq 'checks') {
    foreach ($snowSuite in @('pc_graphics_suite','golden_sunlight_suite','snow_response_suite','snow_readability_suite')) {
        & "$snowRoot/godotw.ps1" --headless --script "tests/$snowSuite.gd"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    foreach ($snowSuite in @('graphics_suite','snow_dreamlike_material_playtest')) {
        & "$snowRoot/godotw.ps1" --script "tests/$snowSuite.gd"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    exit 0
}
if (-not (Test-Path "$snowRoot/artifacts/soft_snow/baseline/manifest.json")) {
    throw 'Prepare the frozen baseline first with scripts/snapshot_snow_material.py; see docs/RENDERING.md.'
}
$snowArgs = @('--script','tests/soft_snow_playtest.gd','--',"--output=res://artifacts/soft_snow/$Stage",'--graphics-quality=high','--upscaler=auto','--render-scale=0.75','--frame-generation=off','--terrain-gi=off','--ui-staged-loading')
if ($Stage -eq 'timing') { $snowArgs += '--timing' }
if ($Stage -eq 'controls') { $snowArgs += '--native-controls' }
& "$snowRoot/godotw.ps1" @snowArgs
exit $LASTEXITCODE
