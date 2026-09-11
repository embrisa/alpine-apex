param([string[]]$Suites = @(
    'arcade_air_suite','controller_input_suite','physics_suite','runtime_suite',
    'rider_lifecycle_suite','competitive_suite','airborne_control_suite','jump_suite',
    'tuck_contact_suite','landing_absorption_suite','rock_terrain_suite',
    'steep_upgrade_suite','steep_motion_suite','airborne_pose_suite','skier_animation_suite','ski_attachment_suite'
), [ValidateRange(0,3600)][int]$LockWaitSeconds = 900)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force 'artifacts/arcade_air_v27' | Out-Null
$airValidationResults = @()
foreach ($airSuite in $Suites) {
    if ($airSuite -notmatch '^[a-z_]+$') { throw 'Invalid suite name.' }
    $airWaitStart = Get-Date
    while ($true) {
        try {
            & ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script',"tests/$airSuite.gd") -Label "air27_$airSuite" -TimeoutSeconds 600
            break
        } catch {
            if ($_.Exception.Message -notmatch 'validation.lock.*being used' -or ((Get-Date)-$airWaitStart).TotalSeconds -gt $LockWaitSeconds) { throw }
            Start-Sleep -Seconds 5
        }
    }
    $airGuard = Get-Content -Raw "artifacts/guarded/air27_$airSuite/guard.json" | ConvertFrom-Json
    $airValidationResults += @{suite=$airSuite;exit_code=$airGuard.exit_code;reason=$airGuard.stop_reason}
    # Preserve receipts from previously completed suites during focused reruns.
    $airAllResults = @()
    if (Test-Path 'artifacts/arcade_air_v27/suites.json') {
        $airAllResults = @(Get-Content -Raw 'artifacts/arcade_air_v27/suites.json' | ConvertFrom-Json | Where-Object { $_.suite -notin $airValidationResults.suite })
    }
    @($airAllResults + $airValidationResults) | ConvertTo-Json -Depth 5 | Set-Content 'artifacts/arcade_air_v27/suites.json'
}
if (@($airValidationResults | Where-Object { $_.exit_code -ne 0 }).Count) { exit 1 }
exit 0
