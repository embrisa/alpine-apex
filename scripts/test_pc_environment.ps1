param(
    [string]$OutputDirectory = 'artifacts/pc_environment/regression',
    [ValidateSet('core','input','graphics','generation')][string]$Profile = 'core',
    [string[]]$Suites,
    [switch]$ContinueOnFailure,
    [switch]$PlanOnly
)
$ErrorActionPreference = 'Stop'
$alpineRoot = Split-Path $PSScriptRoot -Parent
$alpineProfiles = @{
    core = @('physics_suite','runtime_suite')
    input = @('controller_input_suite','haptics_suite','physics_suite','runtime_suite')
    graphics = @('graphics_suite','pc_graphics_suite')
    generation = @('generation_v15_estimate_suite','generation_v15_contract_suite','generation_v15_scenery_integrity_suite')
}
if ($PSBoundParameters.ContainsKey('Suites') -and $PSBoundParameters.ContainsKey('Profile')) { throw 'Choose either -Profile or -Suites.' }
$alpineSelected = @(if ($PSBoundParameters.ContainsKey('Suites')) { $Suites | ForEach-Object { $_ -split ',' | ForEach-Object { $_.Trim() } } } else { $alpineProfiles[$Profile] })
if (-not $alpineSelected.Count) { throw 'Select at least one suite.' }
# Validate the whole plan before taking the engine lock or starting work.
$alpineSeen = [Collections.Generic.HashSet[string]]::new()
foreach ($alpineSuite in $alpineSelected) {
    if ($alpineSuite -notmatch '^[a-z0-9_]+$') { throw "Invalid suite name: $alpineSuite" }
    if (-not $alpineSeen.Add($alpineSuite)) { throw "Duplicate suite: $alpineSuite" }
    if (-not (Test-Path -LiteralPath (Join-Path $alpineRoot "tests/$alpineSuite.gd"))) { throw "Missing suite: $alpineSuite" }
}
$alpinePlan = @{profile=$(if ($PSBoundParameters.ContainsKey('Suites')) {'explicit'} else {$Profile}); suites=@($alpineSelected); stop_on_failure=(-not $ContinueOnFailure)}
if ($PlanOnly) { $alpinePlan | ConvertTo-Json -Depth 4; exit 0 }
# Direct calls own one guard; an outer guard passes its root to the child.
if ($env:ALPINE_VALIDATION_ROOT -ne $alpineRoot) {
    $alpineBatchArgs = @('-NoProfile','-File',$PSCommandPath,'-OutputDirectory',$OutputDirectory)
    if ($PSBoundParameters.ContainsKey('Suites')) { $alpineBatchArgs += @('-Suites',($alpineSelected -join ',')) }
    else { $alpineBatchArgs += @('-Profile',$Profile) }
    if ($ContinueOnFailure) { $alpineBatchArgs += '-ContinueOnFailure' }
    & (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath pwsh -Arguments $alpineBatchArgs -Label "batch-$Profile"
    exit $LASTEXITCODE
}
$alpineOutput = [IO.Path]::GetFullPath($OutputDirectory,$alpineRoot)
New-Item -ItemType Directory -Force $alpineOutput | Out-Null
$alpineResults = [Collections.Generic.List[object]]::new()
$alpineRun = @{started_utc=[DateTime]::UtcNow.ToString('o'); status='running'; plan=$alpinePlan; suites=@($alpineSelected | ForEach-Object { @{suite=$_;status='not_run'} })}
$alpinePreviousTimings = $env:ALPINE_TEST_TIMINGS_DIRECTORY
$env:ALPINE_TEST_TIMINGS_DIRECTORY = $alpineOutput
function Save-AlpineBatch {
    ConvertTo-Json -InputObject @($alpineResults.ToArray()) -Depth 8 | Set-Content -LiteralPath (Join-Path $alpineOutput 'results.json')
    ConvertTo-Json -InputObject $alpineRun -Depth 8 | Set-Content -LiteralPath (Join-Path $alpineOutput 'run.json')
}
Save-AlpineBatch
try {
    for ($alpineIndex=0; $alpineIndex -lt $alpineSelected.Count; $alpineIndex++) {
        $alpineSuite = $alpineSelected[$alpineIndex]
        $alpineStarted = [Diagnostics.Stopwatch]::StartNew()
        $alpineLog = Join-Path $alpineOutput "$alpineSuite.log"
        $alpineErrors = [Collections.Generic.List[string]]::new()
        $alpinePassed = 0
        $alpineReportedPassed = $null
        $alpineStages = [Collections.Generic.List[object]]::new()
        $alpineRun.suites[$alpineIndex].status = 'running'
        Save-AlpineBatch
        Write-Output "SUITE_START $alpineSuite index=$($alpineIndex+1)/$($alpineSelected.Count)"
        $alpineWriter = [IO.StreamWriter]::new($alpineLog,$false,[Text.UTF8Encoding]::new($false))
        $alpineWriter.AutoFlush = $true
        try {
            & (Join-Path $alpineRoot 'godotw.ps1') --headless --script "tests/$alpineSuite.gd" 2>&1 | ForEach-Object {
                $alpineLine = $_.ToString()
                $alpineWriter.WriteLine($alpineLine)
                if ($alpineLine -match '^(SCRIPT ERROR:|ERROR:|FAIL(?::|\s)|Parse Error)') { $alpineErrors.Add($alpineLine) }
                if ($alpineLine -match '^PASS(?::|\s)') { $alpinePassed++ }
                if ($alpineLine -match '^[A-Z][A-Z0-9_]* (\{.*\})$') {
                    $alpineSummary = $Matches[1] | ConvertFrom-Json
                    if ($alpineSummary.PSObject.Properties.Name -contains 'checks') {
                        $alpineSummaryFailures = @($alpineSummary.failures | Where-Object { $null -ne $_ })
                        $alpineReportedPassed = [int]$alpineSummary.checks - $alpineSummaryFailures.Count
                        foreach ($alpineSummaryFailure in $alpineSummaryFailures) { $alpineErrors.Add("Summary failure: $alpineSummaryFailure") }
                    }
                }
                if ($alpineLine -match '^[A-Z][A-Z0-9_]* (\d+) checks; failures=(\[.*\])$') {
                    $alpineSummaryCount = [int]$Matches[1]
                    $alpineSummaryFailures = @($Matches[2] | ConvertFrom-Json)
                    $alpineReportedPassed = $alpineSummaryCount - $alpineSummaryFailures.Count
                    foreach ($alpineSummaryFailure in $alpineSummaryFailures) { $alpineErrors.Add("Summary failure: $alpineSummaryFailure") }
                }
                if ($alpineLine.StartsWith('TEST_STAGE ')) { $alpineStages.Add(($alpineLine.Substring(11) | ConvertFrom-Json)) }
                Write-Output $alpineLine
            }
            $alpineExit = $LASTEXITCODE
        } finally { $alpineWriter.Dispose() }
        if ($null -ne $alpineReportedPassed) { $alpinePassed = $alpineReportedPassed }
        $alpineFailed = $alpineExit -ne 0 -or $alpineErrors.Count -gt 0
        $alpineStatus = if ($alpineFailed) {'failed'} else {'passed'}
        $alpineResults.Add(@{suite=$alpineSuite; status=$alpineStatus; exit_code=$alpineExit; checks_passed=$alpinePassed; errors=@($alpineErrors.ToArray()); seconds=$alpineStarted.Elapsed.TotalSeconds; stages=@($alpineStages.ToArray())})
        $alpineRun.suites[$alpineIndex].status = $alpineStatus
        Save-AlpineBatch
        Write-Output "SUITE_COMPLETE $alpineSuite status=$alpineStatus checks=$alpinePassed seconds=$([math]::Round($alpineStarted.Elapsed.TotalSeconds,3))"
        if ($alpineFailed -and -not $ContinueOnFailure) {
            Write-Output "BATCH_STOP remaining=$($alpineSelected.Count-$alpineIndex-1) reason=failed_suite"
            break
        }
    }
    $alpineRun.status = if (@($alpineResults | Where-Object status -eq 'failed').Count) {'failed'} else {'passed'}
} catch {
    $alpineRun.status = 'failed'
    $alpineRun.error = $_.Exception.Message
    throw
} finally {
    $env:ALPINE_TEST_TIMINGS_DIRECTORY = $alpinePreviousTimings
    $alpineRun.finished_utc = [DateTime]::UtcNow.ToString('o')
    Save-AlpineBatch
}
Write-Output "BATCH_COMPLETE status=$($alpineRun.status) results=$alpineOutput"
if ($alpineRun.status -ne 'passed') { exit 1 }
exit 0
