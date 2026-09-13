param(
    [Parameter(Mandatory)][string]$FilePath,
    [Parameter(Mandatory)][string[]]$Arguments,
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Label = 'validation',
    [ValidateRange(10,3600)][int]$TimeoutSeconds = 1200,
    [ValidateRange(0,86400)][int]$WaitTimeoutSeconds = 3600,
    [ValidateSet('progress','all','quiet')][string]$OutputMode = 'progress',
    # Windows per-process allocation totals include shared resources. By default
    # collect them as telemetry, not as a physical VRAM exhaustion detector.
    [ValidateRange(0,65536)][int]$MaximumGpuMB = 0,
    [switch]$CollectGpuMemory,
    [ValidateSet('Shared','FpsCritical','Exclusive')][string]$WorkloadMode = 'Shared',
    # Exact, case-insensitive keys for shared output/cache writers. By default
    # invocations of the same producer serialize; isolated producers may narrow it.
    [string[]]$ResourceKeys = @(),
    [switch]$FullMountain,
    [string]$FullMountainReason = '',
    [switch]$PlanOnly
)
# Functional runs share admission; measurements and mutations are exclusive.
$ErrorActionPreference = 'Stop'
$guardRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'test_world_policy.ps1')
$guardMapPlan = @(Get-TestWorldPlan (Get-TestWorldProducers $FilePath $Arguments))
if ($PlanOnly) {
    @{maps=$guardMapPlan;full_mountain=[bool]$FullMountain;full_mountain_reason=$FullMountainReason;file=$FilePath;arguments=$Arguments} | ConvertTo-Json -Depth 8
    exit 0
}
Assert-TestWorldSelection ([bool]$FullMountain) $FullMountainReason $guardMapPlan
if ($env:ALPINE_VALIDATION_ROOT -eq $guardRoot) { throw 'Nested validation guards are not allowed. Run the child directly inside the existing guard.' }
$guardOut = Join-Path $guardRoot "artifacts/guarded/$Label"
New-Item -ItemType Directory -Force $guardOut | Out-Null
. (Join-Path $PSScriptRoot 'validation_lease.ps1')
$guardWorkload = Get-ValidationWorkload $FilePath $Arguments $WorkloadMode $ResourceKeys
$WorkloadMode = $guardWorkload.mode
$guardLease = $null
$guardRequested = Get-Date
$guardStart = $null
$guardWait = [Diagnostics.Stopwatch]::StartNew()
$guardWaitSeconds = 0.0
$guardReceipt = Join-Path $guardOut ('request-' + [guid]::NewGuid().ToString('N') + '.json')
$guardLockPath = Join-Path $guardRoot 'artifacts/validation.lock'
$guardOwned = [Collections.Generic.HashSet[int]]::new()
$guardSamples = [Collections.Generic.List[object]]::new()
$guardBackgroundErrors = [Collections.Generic.List[object]]::new()
$guardBackgroundRecords = [Collections.Generic.HashSet[long]]::new()
$guardReason = ''
$guardExit = 1
$guardProcess = $null
$guardJob = $null
$guardStdout = $null
$guardStderr = $null
$guardLaunched = $false
function Write-GuardOutput {
    foreach ($guardPump in @($guardStdout,$guardStderr)) {
        if (-not $guardPump) { continue }
        foreach ($guardLine in $guardPump.Drain()) {
            if ($OutputMode -eq 'quiet') { continue }
            if ($OutputMode -eq 'progress' -and ($guardLine -match '^PASS(?::|\s)' -or -not $guardLine.Trim())) { continue }
            if ($OutputMode -eq 'progress' -and $guardLine.Length -gt 1600) {
                Write-Output ($guardLine.Substring(0,1600) + " ... [full line in $guardOut]")
            } else { Write-Output $guardLine }
        }
    }
}
try {
    $guardNextWaitNotice = 0.0
    $guardLease = New-ValidationLease $guardRoot $WorkloadMode $Label (@("label:$($Label.ToLowerInvariant())") + $guardWorkload.resources)
    while ($true) {
        $guardOwner = Try-ValidationLease $guardLease
        if (-not $guardOwner) { break }
        if ($guardWait.Elapsed.TotalSeconds -ge $guardNextWaitNotice) {
            Write-Output "GUARDED_WAIT $Label mode=$WorkloadMode waited=$([math]::Round($guardWait.Elapsed.TotalSeconds,1))s owner=$guardOwner"
            $guardNextWaitNotice = $guardWait.Elapsed.TotalSeconds + 10
        }
        if ($guardWait.Elapsed.TotalSeconds -ge $WaitTimeoutSeconds) { throw "Validation wait exceeded ${WaitTimeoutSeconds}s; owner=$guardOwner. Existing workload preserved." }
        Start-Sleep -Milliseconds 250
    }
    $guardWaitSeconds = $guardWait.Elapsed.TotalSeconds
    $guardStart = Get-Date
    # Waiters never replace the active owner's receipt or logs.
    $guardReceipt = Join-Path $guardOut 'guard.json'
    if (Test-Path -LiteralPath $guardReceipt) {
        $guardHistory = Join-Path $guardOut ('history/' + $guardStart.ToString('yyyyMMdd-HHmmss-fff'))
        New-Item -ItemType Directory -Force $guardHistory | Out-Null
        foreach ($guardName in @('guard.json','stdout.log','stderr.log')) {
            $guardOld = Join-Path $guardOut $guardName
            if (Test-Path -LiteralPath $guardOld) { Copy-Item -LiteralPath $guardOld -Destination (Join-Path $guardHistory $guardName) }
        }
    }
    if (-not ('AlpineValidationJob' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'guarded_job.cs') }
    if (-not ('AlpineValidationOutput' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'validation_output.cs') }
    $guardJob = [AlpineValidationJob]::new()
    $guardStartInfo = [Diagnostics.ProcessStartInfo]::new()
    $guardStartInfo.FileName = (Get-Command pwsh -ErrorAction Stop).Source
    $guardStartInfo.WorkingDirectory = $guardRoot
    $guardStartInfo.UseShellExecute = $false
    $guardStartInfo.CreateNoWindow = $true
    $guardStartInfo.RedirectStandardOutput = $true
    $guardStartInfo.RedirectStandardError = $true
    $guardStartInfo.RedirectStandardInput = $true
    $guardStartInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $guardStartInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $guardStartInfo.Environment['ALPINE_VALIDATION_ROOT'] = $guardRoot
    $guardStartInfo.Environment['ALPINE_FULL_MOUNTAIN'] = $(if ($FullMountain) {'1'} else {'0'})
    $guardStartInfo.Environment['ALPINE_FULL_MOUNTAIN_REASON'] = $FullMountainReason
    $guardStartInfo.Environment['ALPINE_VALIDATION_MODE'] = $WorkloadMode
    $guardStartInfo.Environment['ALPINE_VALIDATION_RESOURCES'] = ConvertTo-Json -InputObject @($guardWorkload.resources) -Compress
    $guardPayload = @{file=$FilePath;arguments=$Arguments;directory=$guardRoot} | ConvertTo-Json -Compress
    $guardEncoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($guardPayload))
    foreach ($guardArg in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'guarded_child.ps1'),'-Payload',$guardEncoded)) { $guardStartInfo.ArgumentList.Add($guardArg) }
    $guardProcess = [Diagnostics.Process]::Start($guardStartInfo)
    [void]$guardOwned.Add($guardProcess.Id)
    $guardJob.Assign($guardProcess.Handle)
    $guardStdout = [AlpineValidationOutput]::new($guardProcess.StandardOutput,(Join-Path $guardOut 'stdout.log'))
    $guardStderr = [AlpineValidationOutput]::new($guardProcess.StandardError,(Join-Path $guardOut 'stderr.log'))
    $guardProcess.StandardInput.WriteLine('GO')
    $guardProcess.StandardInput.Close()
    $guardLaunched = $true
    Write-Output "GUARDED_START $Label mode=$WorkloadMode waited=$([math]::Round($guardWaitSeconds,2))s logs=$guardOut"
    $guardNextTelemetry = Get-Date
    $guardNextNotice = (Get-Date).AddSeconds(10)
    while (-not $guardProcess.HasExited) {
        Write-GuardOutput
        if ($guardStdout.HasEngineError -or $guardStderr.HasEngineError) { throw 'Engine errors detected; validation stopped.' }
        if (((Get-Date)-$guardStart).TotalSeconds -gt $TimeoutSeconds) { throw 'Validation exceeded its wall-clock limit.' }
        if ((Get-Date) -ge $guardNextNotice) {
            Write-Output "GUARDED_RUNNING $Label elapsed=$([math]::Round(((Get-Date)-$guardStart).TotalSeconds,1))s"
            $guardNextNotice = (Get-Date).AddSeconds(10)
        }
        if ((Get-Date) -lt $guardNextTelemetry) {
            [void]$guardProcess.WaitForExit(100)
            continue
        }
        $guardNextTelemetry = (Get-Date).AddSeconds(2)
        $guardAll = @(Get-CimInstance Win32_Process)
        do {
            $guardAdded = $false
            foreach ($guardRow in $guardAll) {
                if ($guardOwned.Contains([int]$guardRow.ParentProcessId)) { $guardAdded = $guardOwned.Add([int]$guardRow.ProcessId) -or $guardAdded }
            }
        } while ($guardAdded)
        $guardRows = @($guardAll | Where-Object { $guardOwned.Contains([int]$_.ProcessId) })
        $guardPrivate = ($guardRows | Measure-Object PrivatePageCount -Sum).Sum
        $guardResident = ($guardRows | Measure-Object WorkingSetSize -Sum).Sum
        $guardOS = Get-CimInstance Win32_OperatingSystem
        $guardFree = [int64]$guardOS.FreePhysicalMemory * 1024
        $guardGpu = $null
        $guardTaskGpu = $null
        if ($CollectGpuMemory) {
            $guardGpuRows = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory -ErrorAction SilentlyContinue)
            $guardGpu = ($guardGpuRows | Measure-Object DedicatedUsage -Sum).Sum
            $guardTaskGpu = ($guardGpuRows | Where-Object { $_.Name -match '^pid_(\d+)_' -and $guardOwned.Contains([int]$Matches[1]) } | Measure-Object DedicatedUsage -Sum).Sum
        }
        $guardSamples.Add(@{seconds=((Get-Date)-$guardStart).TotalSeconds; free_bytes=$guardFree; task_private_bytes=$guardPrivate; task_working_set_bytes=$guardResident; task_gpu_dedicated_bytes=$guardTaskGpu; total_gpu_dedicated_bytes=$guardGpu})
        if ($MaximumGpuMB -gt 0 -and $null -ne $guardGpu -and $guardGpu -gt $MaximumGpuMB*1MB) { throw 'Dedicated GPU allocations exceeded the explicit validation budget.' }
        if (((Get-Date)-$guardStart).TotalSeconds -gt $TimeoutSeconds) { throw 'Validation exceeded its wall-clock limit.' }
        $guardEvents = @(Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=$guardStart;Id=1001} -ErrorAction SilentlyContinue | Where-Object {
            if ($_.Message -notmatch 'Event Name: LiveKernelEvent' -or $_.Message -notmatch 'P1: (117|141)\s') { return $false }
            # WER can replay old reports after restarting. Use the dump time
            # where available rather than treating that replay as a new fault.
            if ($_.Message -match 'WATCHDOG-(\d{8}-\d{4})\.dmp') {
                return [datetime]::ParseExact($Matches[1],'yyyyMMdd-HHmm',[Globalization.CultureInfo]::InvariantCulture) -ge $guardStart.AddMinutes(-1)
            }
            return $true
        })
        $guardEvents += @(Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$guardStart;Id=4101} -ErrorAction SilentlyContinue)
        $guardAppEvents = @(Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=$guardStart;Id=1000} -ErrorAction SilentlyContinue)
        $guardEvents += @($guardAppEvents | Where-Object { $_.Message -match 'Faulting application name: dwm\.exe,' })
        # An AMD user-mode DLL can fail inside an unrelated app (e.g. Discord
        # Clips) without a device reset. Preserve it as context, not a TDR.
        foreach ($guardAppEvent in $guardAppEvents) {
            if ($guardAppEvent.Message -match 'amdxx64.dll' -and $guardBackgroundRecords.Add([long]$guardAppEvent.RecordId)) {
                $guardBackgroundErrors.Add(@{time=$guardAppEvent.TimeCreated.ToString('o');record_id=$guardAppEvent.RecordId;message=$guardAppEvent.Message})
            }
        }
        if ($guardEvents.Count) { throw 'Windows recorded a display-driver timeout or compositor crash; validation stopped.' }
        $guardProcess.Refresh()
    }
    $guardProcess.WaitForExit()
    $guardExit = $guardProcess.ExitCode
} catch {
    $guardReason = $_.Exception.Message
} finally {
    # The job contains only this invocation and its descendants. Kill on close
    # also handles cancellation of the guard itself and children between polls.
    if ($guardProcess -and -not $guardProcess.HasExited) {
        if ($guardJob) { $guardJob.Stop() }
        if (-not $guardProcess.HasExited) { $guardProcess.Kill($true) }
        $guardProcess.WaitForExit()
    }
    if ($guardJob) { $guardJob.Dispose() }
    if ($guardProcess) {
        foreach ($guardPump in @($guardStdout,$guardStderr)) {
            if (-not $guardPump) { continue }
            try { [void]$guardPump.Completion.GetAwaiter().GetResult() }
            catch { $guardReason = "Output capture failed: $($_.Exception.Message)" }
            if ($guardPump.HasEngineError -or $guardPump.HasTestFailure) { $guardExit=1; if (-not $guardReason) { $guardReason='Engine or test errors in output.' } }
        }
        Write-GuardOutput
    }
    if ($guardReason) { $guardExit=1 }
    if (-not $guardStart) { $guardWaitSeconds = $guardWait.Elapsed.TotalSeconds }
    try {
        @{full_mountain=[bool]$FullMountain;full_mountain_reason=$FullMountainReason;map_plan=$guardMapPlan;exit_code=$guardExit; stop_reason=$guardReason; workload_launched=$guardLaunched; workload_mode=$WorkloadMode; concurrent=($WorkloadMode -eq 'Shared'); resources=$guardWorkload.resources; requested=$guardRequested.ToString('o'); wait_seconds=$guardWaitSeconds; started=$(if ($guardStart) { $guardStart.ToString('o') } else { $null }); finished=(Get-Date).ToString('o'); samples=$guardSamples; background_driver_app_errors=$guardBackgroundErrors; file=$FilePath; arguments=$Arguments; limits=@{wait_seconds=$WaitTimeoutSeconds; workload_seconds=$TimeoutSeconds; gpu_monitoring=[bool]$CollectGpuMemory; gpu_mb=$MaximumGpuMB}} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $guardReceipt
    } finally {
        Close-ValidationLease $guardLease
    }
}
Write-Output "GUARDED_COMPLETE $Label exit=$guardExit $guardReason"
exit $guardExit
