param([string[]]$Suites = @('physics_suite','runtime_suite','downhill_control_suite','downhill_contact_suite','handling_suite','handling_upgrade_suite','high_speed_turns_suite','high_speed_balance_suite','jump_suite','airborne_control_suite','airborne_pose_suite','ski_attachment_suite','turn_anatomy_suite','impact_recovery_suite','rock_terrain_suite','competitive_suite','rider_lifecycle_suite','skier_motion_suite'))
$ErrorActionPreference = 'Stop'
$alpineRoot = Split-Path $PSScriptRoot -Parent
$alpineOutput = Join-Path $alpineRoot 'artifacts/handling_v15'
New-Item -ItemType Directory -Force $alpineOutput | Out-Null
$alpineResultPath = Join-Path $alpineOutput 'regressions.json'
$alpineResults = @()
if (Test-Path -LiteralPath $alpineResultPath) {
    $alpineResults = @(Get-Content -LiteralPath $alpineResultPath -Raw | ConvertFrom-Json | Where-Object { $_.suite -notin $Suites })
}
foreach ($alpineSuite in $Suites) {
    if ($alpineSuite -notmatch '^[a-z_]+$') { throw 'Invalid suite name.' }
    $alpineStarted = [DateTime]::UtcNow
    Write-Output "DOWNHILL_TEST_START $alpineSuite"
    $alpineText = & "$alpineRoot/godotw.ps1" --headless --script "tests/$alpineSuite.gd" 2>&1
    $alpineExit = $LASTEXITCODE
    $alpineText | Set-Content (Join-Path $alpineOutput "$alpineSuite.log")
    $alpineProblems = @($alpineText | Where-Object { $_ -match '^(FAIL:|SCRIPT ERROR:|ERROR:)' } | ForEach-Object { $_.ToString() })
    $alpineResults += @{suite=$alpineSuite; exit_code=$alpineExit; started_utc=$alpineStarted.ToString('o'); seconds=([DateTime]::UtcNow-$alpineStarted).TotalSeconds; problems=$alpineProblems}
    $alpineResults | ConvertTo-Json -Depth 5 | Set-Content $alpineResultPath
    Write-Output "DOWNHILL_TEST_END $alpineSuite exit=$alpineExit problems=$($alpineProblems.Count)"
}
if (@($alpineResults | Where-Object { $_.exit_code -ne 0 -or $_.problems.Count -gt 0 }).Count -gt 0) { exit 1 }
exit 0
