param(
    [Parameter(Mandatory)][string]$FilePath,
    [Parameter(Mandatory)][string[]]$Arguments,
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Label = 'validation',
    [ValidateRange(10,3600)][int]$TimeoutSeconds = 1200,
    # Windows per-process allocation totals include shared resources. By default
    # collect them as telemetry, not as a physical VRAM exhaustion detector.
    [ValidateRange(0,65536)][int]$MaximumGpuMB = 0,
    [switch]$CollectGpuMemory,
    # Explicit opt-in for isolated functional/visual checks. Concurrent runs
    # share machine resources and must not establish performance baselines.
    [switch]$AllowConcurrent
)
# Exclusive by default. Never changes or terminates existing apps.
$ErrorActionPreference = 'Stop'
$guardRoot = Split-Path $PSScriptRoot -Parent
$guardOut = Join-Path $guardRoot "artifacts/guarded/$Label"
New-Item -ItemType Directory -Force $guardOut | Out-Null
$guardLock = $null
if (-not $AllowConcurrent) {
    $guardLock = [IO.File]::Open((Join-Path $guardRoot 'artifacts/validation.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
}
$guardStart = Get-Date
# Preserve previous attempts, especially interrupted runs, before replacing logs.
if (Test-Path -LiteralPath (Join-Path $guardOut 'guard.json')) {
    $guardHistory = Join-Path $guardOut ('history/' + $guardStart.ToString('yyyyMMdd-HHmmss-fff'))
    New-Item -ItemType Directory -Force $guardHistory | Out-Null
    foreach ($guardName in @('guard.json','stdout.log','stderr.log')) {
        $guardOld = Join-Path $guardOut $guardName
        if (Test-Path -LiteralPath $guardOld) { Copy-Item -LiteralPath $guardOld -Destination (Join-Path $guardHistory $guardName) }
    }
}
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
$guardOutFile = $null
$guardErrFile = $null
$guardLaunched = $false
try {
    $guardBusy = @(Get-CimInstance Win32_Process | Where-Object {
        ($_.Name -like 'Godot*.exe' -and $_.CommandLine -match '(--script\s|--import)') -or
        ($_.Name -eq 'blender.exe' -and $_.CommandLine -match '--background')
    })
    if ($guardBusy.Count -and -not $AllowConcurrent) { throw 'Another Godot/Blender workload is active; existing processes were left untouched.' }
    if (-not ('AlpineValidationJob' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'guarded_job.cs') }
    $guardJob = [AlpineValidationJob]::new()
    $guardStartInfo = [Diagnostics.ProcessStartInfo]::new()
    $guardStartInfo.FileName = (Get-Command pwsh -ErrorAction Stop).Source
    $guardStartInfo.WorkingDirectory = $guardRoot
    $guardStartInfo.UseShellExecute = $false
    $guardStartInfo.CreateNoWindow = $true
    $guardStartInfo.RedirectStandardOutput = $true
    $guardStartInfo.RedirectStandardError = $true
    $guardStartInfo.RedirectStandardInput = $true
    $guardPayload = @{file=$FilePath;arguments=$Arguments;directory=$guardRoot} | ConvertTo-Json -Compress
    $guardEncoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($guardPayload))
    foreach ($guardArg in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'guarded_child.ps1'),'-Payload',$guardEncoded)) { $guardStartInfo.ArgumentList.Add($guardArg) }
    $guardProcess = [Diagnostics.Process]::Start($guardStartInfo)
    [void]$guardOwned.Add($guardProcess.Id)
    $guardJob.Assign($guardProcess.Handle)
    $guardOutFile = [IO.FileStream]::new((Join-Path $guardOut 'stdout.log'),[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::Read,1)
    $guardErrFile = [IO.FileStream]::new((Join-Path $guardOut 'stderr.log'),[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::Read,1)
    $guardStdout = $guardProcess.StandardOutput.BaseStream.CopyToAsync($guardOutFile)
    $guardStderr = $guardProcess.StandardError.BaseStream.CopyToAsync($guardErrFile)
    $guardProcess.StandardInput.WriteLine('GO')
    $guardProcess.StandardInput.Close()
    $guardLaunched = $true
    while (-not $guardProcess.HasExited) {
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
        $guardRecent = (Get-Content (Join-Path $guardOut 'stderr.log') -Tail 32 -ErrorAction SilentlyContinue) -join "`n"
        if ($guardRecent -match '(?m)^(ERROR:|SCRIPT ERROR:)') { throw 'Engine errors detected; validation stopped.' }
        Start-Sleep -Seconds 2
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
        if ($guardStdout) { [void]$guardStdout.GetAwaiter().GetResult() }
        if ($guardStderr) { [void]$guardStderr.GetAwaiter().GetResult() }
        if ($guardOutFile) { $guardOutFile.Dispose() }
        if ($guardErrFile) { $guardErrFile.Dispose() }
        $guardText = if ($guardOutFile) { [IO.File]::ReadAllText((Join-Path $guardOut 'stdout.log')) } else { '' }
        $guardErrors = if ($guardErrFile) { [IO.File]::ReadAllText((Join-Path $guardOut 'stderr.log')) } else { '' }
        if (($guardText+"`n"+$guardErrors) -match '(?m)^(ERROR:|SCRIPT ERROR:|FAIL )') { $guardExit=1; if (-not $guardReason) { $guardReason='Engine or test errors in output.' } }
    }
    if ($guardReason) { $guardExit=1 }
    @{exit_code=$guardExit; stop_reason=$guardReason; workload_launched=$guardLaunched; concurrent=[bool]$AllowConcurrent; started=$guardStart.ToString('o'); finished=(Get-Date).ToString('o'); samples=$guardSamples; background_driver_app_errors=$guardBackgroundErrors; file=$FilePath; arguments=$Arguments; limits=@{gpu_monitoring=[bool]$CollectGpuMemory; gpu_mb=$MaximumGpuMB}} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $guardOut 'guard.json')
    if ($guardLock) { $guardLock.Dispose() }
}
Write-Output "GUARDED_COMPLETE $Label exit=$guardExit $guardReason"
exit $guardExit
