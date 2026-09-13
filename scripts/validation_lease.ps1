# Process-held shared/exclusive leases. Admission is serialized only while checking
# reservations; the existing validation.lock stays held for the entire workload.
function Read-ValidationLeaseJson([string]$Path) {
    $reader = [IO.StreamReader]::new([IO.File]::Open($Path,'Open','Read','ReadWrite'))
    try { return $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
}
function Write-ValidationLease($Request) {
    $bytes = [Text.Encoding]::UTF8.GetBytes(($Request.Metadata | ConvertTo-Json -Depth 5 -Compress))
    $Request.Stream.SetLength(0); $Request.Stream.Write($bytes,0,$bytes.Length); $Request.Stream.Flush()
}
function Enter-ValidationAdmission($Request) {
    try { return $Request.Mutex.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { return $true }
}
function New-ValidationLease([string]$Root,[string]$Mode,[string]$Label,[string[]]$Resources) {
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\','/').ToLowerInvariant()
    $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($rootPath)))
    $token = [guid]::NewGuid().ToString('N')
    $directory = Join-Path $Root 'artifacts/validation_leases'
    New-Item -ItemType Directory -Force $directory | Out-Null
    $request = @{
        Directory=$directory; Path=(Join-Path $directory "$token.json"); LockPath=(Join-Path $Root 'artifacts/validation.lock')
        Mutex=[Threading.Mutex]::new($false,"Local\AlpineValidation-$digest"); Stream=$null; Lock=$null
        Metadata=@{schema=2;token=$token;pid=$PID;thread=$env:CODEX_THREAD_ID;label=$Label;mode=$Mode;state='waiting';requested_ticks=[DateTime]::UtcNow.Ticks;resources=@($Resources)}
    }
    # Creation is atomic to other admissions: no reader can observe half a record.
    while (-not (Enter-ValidationAdmission $request)) { Start-Sleep -Milliseconds 20 }
    try {
        $request.Stream = [IO.File]::Open($request.Path,'CreateNew','ReadWrite','Read')
        Write-ValidationLease $request
        if (-not [IO.File]::Exists($request.LockPath)) {
            $initial = [IO.File]::Open($request.LockPath,'OpenOrCreate','ReadWrite','ReadWrite'); $initial.Dispose()
        }
    } catch {
        if ($request.Stream) { $request.Stream.Dispose() }
        throw
    } finally { $request.Mutex.ReleaseMutex() }
    return $request
}
function Get-ValidationLeases($Request) {
    $live = [Collections.Generic.List[object]]::new()
    foreach ($path in [IO.Directory]::GetFiles($Request.Directory,'*.json')) {
        if ($path -eq $Request.Path) { continue }
        $probe = $null
        try { $probe = [IO.File]::Open($path,'Open','ReadWrite','None') }
        catch [IO.IOException] {
            if (($_.Exception.HResult -band 0xffff) -notin @(32,33)) { throw }
        }
        if ($probe) {
            $probe.Dispose(); [IO.File]::Delete($path) # dead process: OS released its lease
        } else { $live.Add((Read-ValidationLeaseJson $path)) }
    }
    return $live.ToArray()
}
function Get-ValidationExternalWork($Request,$Peers) {
    $all = @(Get-CimInstance Win32_Process)
    $known = [Collections.Generic.HashSet[int]]::new()
    [void]$known.Add($PID)
    foreach ($peer in $Peers) { [void]$known.Add([int]$peer.pid) }
    do {
        $added=$false
        foreach ($row in $all) {
            if ($known.Contains([int]$row.ParentProcessId)) { $added=$known.Add([int]$row.ProcessId) -or $added }
        }
    } while ($added)
    return @($all | Where-Object {
        -not $known.Contains([int]$_.ProcessId) -and (
            ($_.Name -like 'Godot*.exe' -and ($Request.Metadata.mode -ne 'Shared' -or $_.CommandLine -match '(--script\s|--import)')) -or
            ($_.Name -eq 'blender.exe' -and $_.CommandLine -match '--background'))
    } | ForEach-Object { "$($_.Name) pid=$($_.ProcessId) (unregistered workload)" })
}
function Try-ValidationLease($Request) {
    if (-not (Enter-ValidationAdmission $Request)) { return 'admission in progress' }
    try {
        $peers = @(Get-ValidationLeases $Request)
        $running = @($peers | Where-Object state -eq 'running')
        $exclusive = $Request.Metadata.mode -ne 'Shared'
        $waiting = @($peers | Where-Object { $_.state -eq 'waiting' -and $_.mode -ne 'Shared' })
        $blockers = @($running | Where-Object {
            $peer = $_
            $exclusive -or $peer.mode -ne 'Shared' -or @($peer.resources | Where-Object { $_ -in $Request.Metadata.resources }).Count -gt 0
        })
        # Writer preference, FIFO among exclusive requests. Shared work already
        # running finishes normally; later readers cannot starve a measurement.
        $blockers += @($waiting | Where-Object {
            -not $exclusive -or $_.requested_ticks -lt $Request.Metadata.requested_ticks -or
            ($_.requested_ticks -eq $Request.Metadata.requested_ticks -and $_.token -lt $Request.Metadata.token)
        })
        if ($blockers.Count) { return ($blockers | ForEach-Object { "$($_.label) pid=$($_.pid) $($_.mode)/$($_.state)" }) -join ', ' }
        try {
            $Request.Lock = [IO.File]::Open($Request.LockPath,'Open',$(if ($exclusive) {'ReadWrite'} else {'Read'}),'Read')
        } catch [IO.IOException] {
            if (($_.Exception.HResult -band 0xffff) -notin @(32,33)) { throw }
            try { return 'external/previous guard: ' + ((Read-ValidationLeaseJson $Request.LockPath) | ConvertTo-Json -Compress) }
            catch { return 'external workload holds validation.lock' }
        }
        $external = @(Get-ValidationExternalWork $Request $peers)
        if ($external.Count) { $Request.Lock.Dispose(); $Request.Lock=$null; return $external -join ', ' }
        $Request.Metadata.state='running'
        Write-ValidationLease $Request
        return ''
    } finally { $Request.Mutex.ReleaseMutex() }
}
function Close-ValidationLease($Request) {
    if (-not $Request) { return }
    while (-not (Enter-ValidationAdmission $Request)) { Start-Sleep -Milliseconds 20 }
    try {
        if ($Request.Lock) { $Request.Lock.Dispose(); $Request.Lock=$null }
        if ($Request.Stream) { $Request.Stream.Dispose(); $Request.Stream=$null }
        [IO.File]::Delete($Request.Path)
    } finally { $Request.Mutex.ReleaseMutex(); $Request.Mutex.Dispose() }
}

function Get-ValidationWorkload([string]$File,[string[]]$TargetArguments,[string]$RequestedMode,[string[]]$ResourceKeys) {
    $entries = [Collections.Generic.List[string]]::new()
    if ($File -match '\.(ps1|gd|py)$') { $entries.Add($File) }
    for ($i=0;$i -lt $TargetArguments.Count-1;$i++) {
        if ($TargetArguments[$i] -in @('-File','--script','-s')) { $entries.Add($TargetArguments[$i+1]) }
    }
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $normalized = @($entries | ForEach-Object {
        $entry = $_.Replace('res://','')
        [IO.Path]::GetRelativePath($projectRoot,[IO.Path]::GetFullPath($entry,$projectRoot)).Replace('\','/').ToLowerInvariant()
    })
    $mode = $RequestedMode
    # Known timing entry points are always exclusive, even if an old command
    # omits the new switch. This is command classification, never title inference.
    if (@($normalized | Where-Object { $_ -match '(^|/)(benchmark_[^/]+\.ps1|[^/]+_benchmark\.gd|[^/]+_cpu_suite\.gd|[^/]+_performance_suite\.gd|performance_descent\.gd|performance_gpu_profile\.gd)$' }).Count -or
        @($TargetArguments | Where-Object { $_ -in @('-ProfileFrameCosts','-ProfileGpuPasses','--profile-frame-costs','--gpu-profile','--case-performance') }).Count) { $mode='FpsCritical' }
    elseif ($mode -ne 'FpsCritical' -and (@($TargetArguments | Where-Object { $_ -in @('--import','--editor','--export-release','--export-debug','--export-pack','--background') }).Count -or
        @($normalized | Where-Object { $_ -match '(^|/)((build_|install_|activate_|setup_)[^/]+\.ps1|prepare_validation_mountain\.gd|interface_mountain_suite\.gd)$' }).Count)) { $mode='Exclusive' }
    $resources = @($ResourceKeys)
    if (-not $resources.Count) {
        # Reserve the producer, not the shared godotw/pwsh launcher.
        if ($normalized.Count) { $resources = @("script:$($normalized[-1])") }
        if (-not $resources.Count) {
            $signature = $File + "`n" + ($TargetArguments -join "`n")
            $resources = @('command:' + [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($signature))))
        }
    }
    return @{mode=$mode;resources=@($resources | ForEach-Object { $_.ToLowerInvariant() } | Select-Object -Unique)}
}
