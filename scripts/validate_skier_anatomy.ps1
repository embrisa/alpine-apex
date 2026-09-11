# Invoke through run_guarded.ps1; one engine at a time and no personal records.
param([ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Evidence = 'skier_anatomy', [switch]$DeepTuck)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
$anatomyOut = "artifacts/$Evidence/regression"
New-Item -ItemType Directory -Force $anatomyOut | Out-Null
$anatomyFailed = $false
$poseSuite = if ($DeepTuck) { 'deep_tuck_suite' } else { 'skier_anatomy_suite' }
foreach ($anatomySuite in @($poseSuite,'physics_suite','runtime_suite','airborne_pose_suite','equipment_asset_suite','rider_lifecycle_suite','steep_motion_gameplay_ui','steep_pose_budget_suite')) {
    $anatomyLog = "$anatomyOut/$anatomySuite.log"
    & ./godotw.ps1 --headless --script "tests/$anatomySuite.gd" *> $anatomyLog
    $anatomyCode = $LASTEXITCODE
    $anatomyErrors = @(Select-String -LiteralPath $anatomyLog -Pattern '^ERROR:|^SCRIPT ERROR:|^FAIL:')
    Write-Output "$anatomySuite exit=$anatomyCode errors=$($anatomyErrors.Count)"
    if ($anatomyCode -ne 0 -or $anatomyErrors.Count) { $anatomyFailed = $true }
}
exit $(if ($anatomyFailed) { 1 } else { 0 })
