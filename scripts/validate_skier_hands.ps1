# Run through run_guarded.ps1. Keeps validation separate from personal records.
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
$handResults = @()
New-Item -ItemType Directory -Force artifacts/hands_v1/regression | Out-Null
foreach ($handSuite in @('skier_motion_suite','skier_anatomy_suite')) {
    $handLog = "artifacts/hands_v1/regression/$handSuite.log"
    & ./godotw.ps1 --headless --script "tests/$handSuite.gd" *> $handLog
    $handCode = $LASTEXITCODE
    $handErrors = @(Select-String -LiteralPath $handLog -Pattern '^FAIL:|^ERROR:|^SCRIPT ERROR:')
    $handChecks = @(Select-String -LiteralPath $handLog -Pattern '^PASS:|^FAIL:').Count
    $handResults += @{suite=$handSuite; exit_code=$handCode; checks=$handChecks; errors=@($handErrors | ForEach-Object { $_.Line })}
    Write-Output "$handSuite exit=$handCode checks=$handChecks errors=$($handErrors.Count)"
}
$handResults | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath artifacts/hands_v1/regression/results.json
if (@($handResults | Where-Object { $_.exit_code -ne 0 -or $_.errors.Count -gt 0 }).Count) { exit 1 }
exit 0
