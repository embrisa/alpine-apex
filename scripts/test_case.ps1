param(
    [Parameter(Mandatory)][string]$Case,
    [ValidateSet('Inspect','Capture','Rerun')][string]$Mode = 'Inspect',
    [string]$Output = '',
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Label = ('test-case-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
)
$ErrorActionPreference = 'Stop'
$caseRoot = Split-Path $PSScriptRoot -Parent
$caseFile = (Resolve-Path -LiteralPath $Case).Path
if (-not $Output) { $Output = Join-Path $caseRoot "artifacts/test_cases/$Label-$Mode" }
$caseOutput = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath (Join-Path $caseOutput 'result.json')) { throw 'Choose a fresh output directory; prior results are preserved.' }
$caseArguments = @('--script','scripts/diagnostics/case_tool.gd','--',"--case=$caseFile","--case-output=$caseOutput","--case-mode=$Mode",'--ui-staged-loading','--benchmark-no-captures')
if ($Mode -ne 'Capture') { $caseArguments = @('--headless') + $caseArguments }
Push-Location $caseRoot
try {
    if ($env:ALPINE_VALIDATION_ROOT -eq $caseRoot) {
        & ./godotw.ps1 @caseArguments
    } else {
        & ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments $caseArguments -Label $Label -TimeoutSeconds 1200
    }
    exit $LASTEXITCODE
} finally { Pop-Location }
