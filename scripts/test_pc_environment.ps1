param([string]$OutputDirectory = 'artifacts/pc_environment/regression', [string[]]$Suites = @('physics_suite','runtime_suite','graphics_suite','pc_graphics_suite','golden_sunlight_suite','mountain_suite','generated_mountain_suite','mountain_library_suite','summit_mountain_suite','technical_showcase_suite','technical_showcase_hazards','technical_showcase_v6_suite','technical_showcase_v6_hazards','technical_showcase_v7_suite','technical_showcase_v7_hazards','race_suite','competitive_suite'))
$ErrorActionPreference = 'Stop'
$alpineRoot = Split-Path $PSScriptRoot -Parent
$alpineOutput = Join-Path $alpineRoot $OutputDirectory
New-Item -ItemType Directory -Force $alpineOutput | Out-Null
$alpineResults = @()
foreach ($alpineSuite in $Suites) {
    if ($alpineSuite -notmatch '^[a-z0-9_]+$') { throw 'Invalid suite name.' }
    $alpineStarted = [DateTime]::UtcNow
    $alpineLog = Join-Path $alpineOutput "$alpineSuite.log"
    & (Join-Path $alpineRoot 'godotw.ps1') --headless --script "tests/$alpineSuite.gd" *> $alpineLog
    $alpineExit = $LASTEXITCODE
    $alpineErrors = @(Select-String -LiteralPath $alpineLog -Pattern 'SCRIPT ERROR:|^ERROR:|^FAIL:|Parse Error')
    $alpinePassed = @(Select-String -LiteralPath $alpineLog -Pattern '^PASS:').Count
    $alpineResults += @{suite=$alpineSuite;exit_code=$alpineExit;checks_passed=$alpinePassed;errors=@($alpineErrors | ForEach-Object { $_.Line });seconds=([DateTime]::UtcNow-$alpineStarted).TotalSeconds}
    $alpineResults | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $alpineOutput 'results.json')
    Write-Output "SUITE $alpineSuite exit=$alpineExit checks=$alpinePassed errors=$($alpineErrors.Count)"
}
if (@($alpineResults | Where-Object { $_.exit_code -ne 0 -or $_.errors.Count -gt 0 }).Count -gt 0) { exit 1 }
