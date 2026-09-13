param(
    [Parameter(Mandatory)][string]$Case,
    [ValidateSet('Inspect','Capture','Rerun','RerunCapture')][string]$Mode = 'Inspect',
    [ValidateRange(2,120)][int]$CaptureFrames = 8,
    [string]$Output = '',
    [switch]$FullMountain = ($env:ALPINE_FULL_MOUNTAIN -eq '1'),
    [string]$FullMountainReason = $env:ALPINE_FULL_MOUNTAIN_REASON,
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Label = ('test-case-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
)
$ErrorActionPreference = 'Stop'
$caseRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'test_world_policy.ps1')
Assert-TestWorldSelection ([bool]$FullMountain) $FullMountainReason
$caseFile = (Resolve-Path -LiteralPath $Case).Path
if (-not $Output) { $Output = Join-Path $caseRoot "artifacts/test_cases/$Label-$Mode" }
$caseOutput = [IO.Path]::GetFullPath($Output,$caseRoot)
if (Test-Path -LiteralPath $caseOutput) { throw 'Choose a fresh output directory; prior results are preserved.' }
$caseArguments = @('--script','scripts/diagnostics/case_tool.gd','--',"--case=$caseFile","--case-output=$caseOutput","--case-mode=$Mode","--case-capture-frames=$CaptureFrames",'--ui-staged-loading','--benchmark-no-captures')
if ($Mode -notin @('Capture','RerunCapture')) { $caseArguments = @('--headless') + $caseArguments }
Push-Location $caseRoot
try {
    if ($env:ALPINE_VALIDATION_ROOT -eq $caseRoot) {
        & ./godotw.ps1 @caseArguments
    } else {
        & ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments $caseArguments -Label $Label -TimeoutSeconds 1200 -WorkloadMode Shared -FullMountain:$FullMountain -FullMountainReason $FullMountainReason
    }
    exit $LASTEXITCODE
} finally { Pop-Location }
