param([string]$Evidence = 'animation_workshop')
$ErrorActionPreference = 'Stop'
$workshopRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $workshopRoot
$workshopOutput = Join-Path $workshopRoot "artifacts/$Evidence/regression"
New-Item -ItemType Directory -Force $workshopOutput | Out-Null
foreach ($workshopSuite in @('animation_workshop_suite','animation_workshop_playtest','animation_workshop_lifecycle','physics_suite','runtime_suite','steep_motion_suite','skier_anatomy_suite','ski_attachment_suite','rider_lifecycle_suite')) {
    $workshopLog = Join-Path $workshopOutput "$workshopSuite.log"
    & ./godotw.ps1 --headless --script "tests/$workshopSuite.gd" *> $workshopLog
    $workshopCode = $LASTEXITCODE
    $workshopErrors = @(Select-String -LiteralPath $workshopLog -Pattern '^ERROR:|^SCRIPT ERROR:|^FAIL:')
    Write-Output "$workshopSuite exit=$workshopCode errors=$($workshopErrors.Count)"
    if ($workshopCode -ne 0 -or $workshopErrors.Count -gt 0) { Get-Content -LiteralPath $workshopLog -Tail 35; exit 1 }
}
