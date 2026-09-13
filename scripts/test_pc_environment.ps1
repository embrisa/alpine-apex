param(
    [string]$OutputDirectory = 'artifacts/pc_environment/regression',
    [ValidateSet('core','input','graphics','generation')][string]$Profile = 'core',
    [string[]]$Suites,
    [switch]$ContinueOnFailure,
    [switch]$PlanOnly,
    [switch]$FullMountain = ($env:ALPINE_FULL_MOUNTAIN -eq '1'),
    [string]$FullMountainReason = $env:ALPINE_FULL_MOUNTAIN_REASON
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
. (Join-Path $PSScriptRoot 'test_world_policy.ps1')
$alpineMapPlan = @(Get-TestWorldPlan @($alpineSelected | ForEach-Object {"tests/$_.gd"}))
$alpinePlan = @{profile=$(if ($PSBoundParameters.ContainsKey('Suites')) {'explicit'} else {$Profile}); suites=@($alpineSelected); stop_on_failure=(-not $ContinueOnFailure); maps=$alpineMapPlan;full_mountain=[bool]$FullMountain;full_mountain_reason=$FullMountainReason}
if ($PlanOnly) { $alpinePlan | ConvertTo-Json -Depth 8; exit 0 }
Assert-TestWorldSelection ([bool]$FullMountain) $FullMountainReason $alpineMapPlan
. (Join-Path $PSScriptRoot 'validation_lease.ps1')
$alpineMode = 'Shared'
foreach ($alpineSuite in $alpineSelected) {
    $classification = Get-ValidationWorkload './godotw.ps1' @('--script',"tests/$alpineSuite.gd") 'Shared' @()
    if ($classification.mode -ne 'Shared') { $alpineMode = $classification.mode }
}
if ($env:ALPINE_VALIDATION_ROOT -eq $alpineRoot -and $alpineMode -eq 'FpsCritical' -and $env:ALPINE_VALIDATION_MODE -ne 'FpsCritical') {
    throw 'Timing suites require a FpsCritical guard; run the batch directly or select that outer workload mode.'
}
$alpineKeys = @($alpineSelected | ForEach-Object { "script:tests/$_.gd" }) + @("output:$([IO.Path]::GetFullPath($OutputDirectory,$alpineRoot))")
if ($env:ALPINE_VALIDATION_ROOT -eq $alpineRoot -and $env:ALPINE_VALIDATION_MODE -eq 'Shared') {
    $inheritedKeys = @($env:ALPINE_VALIDATION_RESOURCES | ConvertFrom-Json)
    if (@($alpineKeys | Where-Object { $_ -notin $inheritedKeys }).Count) {
        throw 'Inherited shared guard does not reserve this batch suite/output scope. Run the batch directly or reserve its complete scope in the outer guard.'
    }
}
# Direct calls own one guard; an outer guard passes its root to the child.
if ($env:ALPINE_VALIDATION_ROOT -ne $alpineRoot) {
    $alpineBatchArgs = @('-NoProfile','-File',$PSCommandPath,'-OutputDirectory',$OutputDirectory)
    if ($PSBoundParameters.ContainsKey('Suites')) { $alpineBatchArgs += @('-Suites',($alpineSelected -join ',')) }
    else { $alpineBatchArgs += @('-Profile',$Profile) }
    if ($ContinueOnFailure) { $alpineBatchArgs += '-ContinueOnFailure' }
    $alpineLabel = 'batch-' + [guid]::NewGuid().ToString('N').Substring(0,10)
    & (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath pwsh -Arguments $alpineBatchArgs -Label $alpineLabel -WorkloadMode $alpineMode -ResourceKeys $alpineKeys -FullMountain:$FullMountain -FullMountainReason $FullMountainReason
    exit $LASTEXITCODE
}
$alpineOutput = [IO.Path]::GetFullPath($OutputDirectory,$alpineRoot)
New-Item -ItemType Directory -Force $alpineOutput | Out-Null
$alpineResults = [Collections.Generic.List[object]]::new()
$alpineRun = @{started_utc=[DateTime]::UtcNow.ToString('o'); status='running'; plan=$alpinePlan; suites=@($alpineSelected | ForEach-Object { @{suite=$_;status='not_run'} })}
$alpineIdentityJson = & python (Join-Path $alpineRoot 'scripts/versioning.py') identity --root $alpineRoot --json
if ($LASTEXITCODE) { throw 'Could not identify regression checkout.' }
$alpineRun.build = ($alpineIdentityJson | ConvertFrom-Json)
$alpineRun.test_inputs = @{}
foreach ($alpineSuite in $alpineSelected) { $alpineRun.test_inputs[$alpineSuite] = (Get-FileHash -LiteralPath (Join-Path $alpineRoot "tests/$alpineSuite.gd") -Algorithm SHA256).Hash.ToLowerInvariant() }
if (Test-Path -LiteralPath (Join-Path $alpineRoot "scripts/resolve_godot_engine.ps1")) {
    . (Join-Path $alpineRoot "scripts/resolve_godot_engine.ps1")
    $alpineTestEngine = Get-AlpineGodotEngine -ProjectRoot $alpineRoot -InvocationArguments @("--headless","--script","tests/$($alpineSelected[0]).gd")
    $alpineRun.build | Add-Member -NotePropertyName engine_sha256 -NotePropertyValue (Get-FileHash -LiteralPath $alpineTestEngine -Algorithm SHA256).Hash.ToLowerInvariant()
}
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
        $alpineResults.Add(@{suite=$alpineSuite; build=$alpineRun.build; status=$alpineStatus; exit_code=$alpineExit; checks_passed=$alpinePassed; errors=@($alpineErrors.ToArray()); seconds=$alpineStarted.Elapsed.TotalSeconds; stages=@($alpineStages.ToArray())})
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
    $alpineFinalIdentity = & python (Join-Path $alpineRoot 'scripts/versioning.py') identity --root $alpineRoot --json
    if ($LASTEXITCODE) { $alpineRun.status = 'failed'; $alpineRun.error = 'Could not check final source identity.' }
    else {
        $alpineRun.finished_build = ($alpineFinalIdentity | ConvertFrom-Json)
        $alpineRun.stable_build_sources = $alpineRun.build.source_sha256 -eq $alpineRun.finished_build.source_sha256
        foreach ($alpineSuite in $alpineSelected) {
            if ((Get-FileHash -LiteralPath (Join-Path $alpineRoot "tests/$alpineSuite.gd") -Algorithm SHA256).Hash.ToLowerInvariant() -ne $alpineRun.test_inputs[$alpineSuite]) { $alpineRun.stable_build_sources = $false }
        }
        if (-not $alpineRun.stable_build_sources) { $alpineRun.status = 'failed'; $alpineRun.error = 'Game/build inputs changed during regression.' }
    }
    Save-AlpineBatch
}
Write-Output "BATCH_COMPLETE status=$($alpineRun.status) results=$alpineOutput"
if ($alpineRun.status -ne 'passed') { exit 1 }
exit 0
