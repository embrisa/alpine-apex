# Invoke this whole batch through scripts/run_guarded.ps1; it owns no extra lock.
$ErrorActionPreference = 'Stop'
$motionRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $motionRoot
$motionFailed = $false
$motionBeforeHash = (Get-FileHash -LiteralPath 'assets/animation/steep_ski_motion.res' -Algorithm SHA256).Hash
& ./godotw.ps1 --headless --script scripts/art/export_ski_motion.gd *> artifacts/steep_motion_gameplay/export-final.log
if ($LASTEXITCODE -ne 0) { throw 'Motion export failed; see export-final.log' }
$motionAfterHash = (Get-FileHash -LiteralPath 'assets/animation/steep_ski_motion.res' -Algorithm SHA256).Hash
Write-Output "Motion resource repeat hash equal: $($motionBeforeHash -eq $motionAfterHash)"
if ($motionBeforeHash -ne $motionAfterHash) { throw 'Repeated motion export changed bytes; audit before validating runtime.' }
foreach ($motionSuite in @('steep_motion_suite','steep_motion_gameplay_ui','equipment_asset_suite','rider_lifecycle_suite')) {
    & ./godotw.ps1 --headless --script "tests/$motionSuite.gd" *> "artifacts/steep_motion_gameplay/regression/$motionSuite.log"
    $motionCode = $LASTEXITCODE
    $motionErrors = @(Select-String -LiteralPath "artifacts/steep_motion_gameplay/regression/$motionSuite.log" -Pattern '^ERROR:|^SCRIPT ERROR:|^FAIL:')
    Write-Output "$motionSuite exit=$motionCode errors=$($motionErrors.Count)"
    if ($motionCode -ne 0 -or $motionErrors.Count) { $motionFailed = $true }
}
exit $(if ($motionFailed) { 1 } else { 0 })
