param([string[]]$Suites = @('physics_suite','runtime_suite','planted_snow_suite','tuck_contact_suite','downhill_contact_suite','arcade_carving_suite','skid_response_suite','high_speed_turns_suite','high_speed_balance_suite','jump_suite','airborne_control_suite','landing_absorption_suite','impact_recovery_suite','rock_terrain_suite','ski_attachment_suite','skier_anatomy_suite','snow_response_suite','competitive_suite','rider_lifecycle_suite','mountain_library_suite'))
$ErrorActionPreference = 'Stop'
$snowProject = Split-Path $PSScriptRoot -Parent
$snowResults = @()
foreach ($snowSuite in $Suites) {
    $snowPath = Join-Path $snowProject "tests/$snowSuite.gd"
    if (-not (Test-Path -LiteralPath $snowPath)) { throw "Missing suite: $snowSuite" }
    # The previous guarded shell may still be closing its file handles.
    $snowDeadline = (Get-Date).AddSeconds(60)
    do {
        $snowReady = $false
        try {
            $snowLock = [IO.File]::Open((Join-Path $snowProject 'artifacts/validation.lock'),'Open','ReadWrite','None')
            $snowLock.Dispose(); $snowReady = $true
        } catch {
            if ((Get-Date) -ge $snowDeadline) { throw }
            Start-Sleep -Milliseconds 1000
        }
    } while (-not $snowReady)
    & "$PSScriptRoot/run_guarded.ps1" -FilePath "$snowProject/godotw.ps1" -Arguments @('--headless','--script',"tests/$snowSuite.gd") -Label "planted_$snowSuite" -TimeoutSeconds 900
    $snowResults += @{suite=$snowSuite;exit_code=$LASTEXITCODE}
    $snowResults | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $snowProject 'artifacts/planted_snow/regression.json')
    Write-Output "SNOW_REGRESSION $snowSuite exit=$LASTEXITCODE"
}
if (@($snowResults | Where-Object { $_.exit_code -ne 0 }).Count) { exit 1 }
