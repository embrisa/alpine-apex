param([ValidateSet('headless','native')][string]$Mode = 'headless')
$ErrorActionPreference = 'Stop'
$workshopRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $workshopRoot
$workshopSuites = @('animation_workshop_suite','animation_workshop_playtest')
foreach ($workshopSuite in $workshopSuites) {
    $workshopArguments = @('--script', "tests/$workshopSuite.gd")
    if ($Mode -ne 'native' -or $workshopSuite -ne 'animation_workshop_playtest') { $workshopArguments = @('--headless') + $workshopArguments }
    & ./godotw.ps1 @workshopArguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
if ($Mode -eq 'native') {
    & ./godotw.ps1 --headless --script tests/animation_workshop_package_suite.gd
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
