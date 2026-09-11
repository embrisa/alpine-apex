param([switch]$Worker,[ValidateSet('checks','visual','mountain','timing')][string]$Stage = 'checks')
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
    & "$PSScriptRoot/run_guarded.ps1" -FilePath pwsh -Arguments @('-NoProfile','-File',$PSCommandPath,'-Worker','-Stage',$Stage) -Label "snow-contact-$Stage" -TimeoutSeconds 1200
    exit $LASTEXITCODE
}
if ($Stage -eq 'checks') {
    foreach ($snowSuite in @('snow_response_suite','snow_contact_visual_suite','rock_terrain_suite')) {
        & "$snowRoot/godotw.ps1" --headless --script "tests/$snowSuite.gd"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & "$snowRoot/godotw.ps1" --script tests/powder_upload_suite.gd
    exit $LASTEXITCODE
}
foreach ($snowReference in @($true,$false)) {
    $snowArgs = @('--script','tests/snow_contact_playtest.gd','--','--graphics-quality=high','--frame-generation=off','--terrain-gi=off')
    if ($snowReference) { $snowArgs += '--reference' }
    if ($Stage -eq 'mountain') { $snowArgs += '--mountain' }
    if ($Stage -eq 'timing') { $snowArgs += '--timing' }
    & "$snowRoot/godotw.ps1" @snowArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
