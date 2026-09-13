param(
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Label = 'v15_high_clear',
    [ValidateSet(-1,1)][int]$Side = -1,
    [ValidateSet('clear','cloudy','snowfall','rain','snowstorm','thunderstorm')][string]$Weather = 'clear',
    [ValidateSet('dawn','day','dusk','night')][string]$TimeOfDay = 'day',
    [ValidateSet(6,7,8,9,10,11,12,13,14,15)][int]$Version = 15,
    [ValidateRange(0,5)][int]$Face = 0,
    [ValidateRange(0,2147483647)][int]$Seed = 849205174,
    [string]$RenderScale = '0.75',
    [ValidateSet('auto','fsr4','fsr3','fsr2','native')][string]$Upscaler = 'auto',
    [ValidateSet('on','off')][string]$TerrainGI = 'off',
    [ValidateSet('on','off')][string]$FrameGeneration = 'off',
    [switch]$ProfileFrameCosts,
    [switch]$ProfileGpuPasses,
    [switch]$ScenarioReplay,
    [ValidateRange(0,300)][int]$StressSpeedKmh = 0,
    [switch]$ColdCollision,
    [ValidateRange(1,10)][int]$Repetitions = 1,
    [ValidateRange(1,60)][int]$TrialSeconds = 15,
    [ValidateRange(0,600)][int]$TrialStartSeconds = 90,
    [string]$InputTrace = 'res://artifacts/fps_optimization/descent_input.json',
    [ValidateSet(0,90,120,144)][int]$FrameCap = 120,
    [ValidateRange(0,2400)][int]$StartZ = 0,
    [ValidateRange(2450,2850)][int]$EndZ = 2850,
    [switch]$SkierAnimationOff,
    [ValidateSet('on','off')][string]$Wilderness = 'on',
    [switch]$WildernessSummit,
    [switch]$OffmapComparison,
    [switch]$OffmapBaseline,
    [switch]$OffmapPaired,
    [switch]$ThirdPerson,
    [switch]$VoiceBenchmark,
    [switch]$VoiceObserverOff,
    [string]$ProjectRoot = ''
)
$ErrorActionPreference = 'Stop'
$alpineRoot = Split-Path $PSScriptRoot -Parent
if ($ProjectRoot) { $alpineRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path }
. (Join-Path $PSScriptRoot "resolve_godot_engine.ps1")
$alpineEngine = Get-AlpineGodotEngine -ProjectRoot $alpineRoot
if ($StressSpeedKmh -gt 0 -and (-not $ScenarioReplay -or $Version -lt 14 -or $OffmapComparison -or $OffmapBaseline -or $OffmapPaired -or $WildernessSummit -or $VoiceBenchmark)) { throw "Speed-controlled stress requires the production scenario benchmark and a matching stress trace." }
if ($Version -ge 14 -and -not ($OffmapComparison -or $OffmapBaseline -or $OffmapPaired -or $WildernessSummit -or $VoiceBenchmark)) {
    if ($Seed -ne 849205174 -or $StartZ -ne 0 -or $EndZ -ne 2850 -or $SkierAnimationOff) {
        throw 'The production benchmark requires the complete default mountain with production animation. Generate a matching ordinary-input trace for other workloads.'
    }
    $traceFile = if ($InputTrace.StartsWith('res://')) { Join-Path $alpineRoot $InputTrace.Substring(6) } else { $InputTrace }
    if (-not (Test-Path -LiteralPath $traceFile)) { throw 'Generate the current input trace with tests/performance_trace.gd first.' }
    $traceData = Get-Content -LiteralPath $traceFile -Raw | ConvertFrom-Json
    if ($PSBoundParameters.ContainsKey('Face') -and $Face -ne $traceData.face) { throw 'Requested face does not match the input trace.' }
    $Face = [int]$traceData.face
    $traceSide = if ($traceData.result.side -eq 0) { -1 } else { 1 }
    if ($PSBoundParameters.ContainsKey('Side') -and $Side -ne $traceSide) { throw 'Requested side does not match the input trace.' }
    if ($Wilderness -ne 'on') { throw 'The production benchmark keeps the complete mountain environment enabled.' }
    $Side = $traceSide
}
$alpineParsedScale = 0.0
if (-not [double]::TryParse($RenderScale,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$alpineParsedScale)) { throw 'Invalid render scale.' }
$alpineOutput = Join-Path $alpineRoot "artifacts/pc_environment/$Label"
New-Item -ItemType Directory -Force $alpineOutput | Out-Null
$alpinePlaytest = if ($Version -ge 10) { 'tests/massif_playtest.gd' } else { 'tests/technical_showcase_playtest.gd' }
if ($Version -eq 12) { $alpinePlaytest = 'tests/alpine_v12_playtest.gd' }
if ($Version -eq 13) { $alpinePlaytest = 'tests/alpine_v13_playtest.gd' }
if ($ProfileGpuPasses -and ($Version -lt 14 -or $OffmapComparison -or $OffmapBaseline -or $OffmapPaired -or $WildernessSummit -or $VoiceBenchmark)) { throw 'GPU pass profiling requires the production trace benchmark.' }
if ($Version -ge 14) { $alpinePlaytest = if ($ProfileGpuPasses) { 'tests/performance_gpu_profile.gd' } else { 'tests/performance_descent.gd' } }
if ($OffmapComparison -or $OffmapBaseline) { $alpinePlaytest = 'tests/offmap_descent.gd' }
if ($OffmapPaired) { $alpinePlaytest = 'tests/offmap_descent_pair.gd' }
if ($WildernessSummit) { $alpinePlaytest = 'tests/wilderness_benchmark.gd' }
if ($VoiceBenchmark) { $alpinePlaytest = 'tests/skier_voice_benchmark.gd' }
$alpineArgs = @('--path',$alpineRoot,'--script',$alpinePlaytest,'--',"--version=$Version","--face=$Face","--seed=$Seed","--side=$Side","--weather=$Weather","--time-of-day=$TimeOfDay","--benchmark-label=$Label",'--benchmark-resolution=3840x2160','--graphics-quality=high',"--render-scale=$RenderScale","--upscaler=$Upscaler","--fps-limit=$FrameCap","--terrain-gi=$TerrainGI","--frame-generation=$FrameGeneration")
if ($ProfileGpuPasses) { $alpineArgs = @('--gpu-profile') + $alpineArgs }
$alpineArgs += @("--benchmark-start=$StartZ","--benchmark-end=$EndZ")
if ($Version -ge 14) {
    $alpineArgs += @("--input-trace=$InputTrace","--repetitions=$Repetitions",'--benchmark-no-captures')
    # An ordinary scenario starts at launch and stops at the exact recorded tick.
    # Benchmark windows remain opt-in for scenarios, including fractional clips.
    $alpineWindowRequested = $PSBoundParameters.ContainsKey('TrialSeconds') -or $PSBoundParameters.ContainsKey('TrialStartSeconds')
    if (-not $ScenarioReplay -or $alpineWindowRequested) {
        if ($ScenarioReplay -and -not $PSBoundParameters.ContainsKey('TrialStartSeconds')) { $TrialStartSeconds = 0 }
        $alpineArgs += @("--trial-seconds=$TrialSeconds","--trial-start-seconds=$TrialStartSeconds")
    }
}
elseif (-not $ThirdPerson) { $alpineArgs += '--pov-forest' }
if ($ProfileFrameCosts) { $alpineArgs += '--profile-frame-costs' }
if ($ScenarioReplay) { $alpineArgs += '--scenario-replay' }
if ($StressSpeedKmh -gt 0) { $alpineArgs += "--stress-speed-kmh=$StressSpeedKmh" }
if ($ColdCollision) { $alpineArgs += '--cold-collision' }
if ($Version -ge 10 -and -not $WildernessSummit) { $alpineArgs += '--ui-staged-loading' }
$alpineArgs += "--wilderness=$Wilderness"
if ($VoiceBenchmark) { $alpineArgs += $(if ($VoiceObserverOff) { '--voice-observer=off' } else { '--voice-observer=on' }) }
if ($WildernessSummit) { $alpineArgs += '--views' }
if ($OffmapBaseline) { $alpineArgs += '--offmap-baseline' }
if ($SkierAnimationOff) { $alpineArgs += '--skier-animation-off' }
if ($ThirdPerson) { $alpineArgs = @($alpineArgs | Where-Object { $_ -ne '--pov-forest' }) }
$alpineStarted = [DateTime]::UtcNow
function Get-AlpineSourceHashes {
    $alpineHashes = @{}
    foreach ($alpineFolder in @('scripts','config','assets','tests','scenes')) {
        Get-ChildItem (Join-Path $alpineRoot $alpineFolder) -Recurse -File | Where-Object { $_.Extension -in @('.gd','.gdshader','.gdshaderinc','.tres','.tscn','.json','.ps1','.cs') } | ForEach-Object { $alpineHashes[$_.FullName.Substring($alpineRoot.Length+1)] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    }
    $alpineHashes['project.godot'] = (Get-FileHash -LiteralPath (Join-Path $alpineRoot 'project.godot') -Algorithm SHA256).Hash
    $alpineHashes['main.tscn'] = (Get-FileHash -LiteralPath (Join-Path $alpineRoot 'main.tscn') -Algorithm SHA256).Hash
    return $alpineHashes
}
$alpineSourcesBefore = Get-AlpineSourceHashes
$alpineEnvironment = @{
    weather = $Weather; time_of_day = $TimeOfDay; weather_seed = 849205174
    os = Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber
    video = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,DriverDate,CurrentHorizontalResolution,CurrentVerticalResolution)
    logical_processors = [Environment]::ProcessorCount
}
$alpinePreviousCpu = @{}
$alpinePreviousTelemetry = [DateTime]::UtcNow
foreach ($alpineExisting in Get-Process) { $alpinePreviousCpu[$alpineExisting.Id] = $alpineExisting.CPU }
if (-not ('AlpineValidationOutput' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'validation_output.cs') }
$alpineStartInfo = [Diagnostics.ProcessStartInfo]::new()
$alpineStartInfo.FileName = $alpineEngine
$alpineStartInfo.WorkingDirectory = $alpineRoot
$alpineStartInfo.UseShellExecute = $false
$alpineStartInfo.CreateNoWindow = $true
$alpineStartInfo.RedirectStandardOutput = $true
$alpineStartInfo.RedirectStandardError = $true
$alpineStartInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
$alpineStartInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
foreach ($alpineArg in $alpineArgs) { $alpineStartInfo.ArgumentList.Add($alpineArg) }
$alpineProcess = [Diagnostics.Process]::Start($alpineStartInfo)
$alpineStdout = [AlpineValidationOutput]::new($alpineProcess.StandardOutput,(Join-Path $alpineOutput 'stdout.log'))
$alpineStderr = [AlpineValidationOutput]::new($alpineProcess.StandardError,(Join-Path $alpineOutput 'stderr.log'))
$alpineSamples = [Collections.Generic.List[object]]::new()
$alpineWorker = $alpineProcess
$alpineNextTelemetry = Get-Date
$alpineFailure = ''
try {
while (-not $alpineProcess.HasExited) {
    foreach ($alpinePump in @($alpineStdout,$alpineStderr)) { foreach ($alpineLine in $alpinePump.Drain()) { Write-Output $alpineLine } }
    if ($alpineStdout.HasEngineError -or $alpineStderr.HasEngineError) { throw 'Engine errors detected; benchmark stopped.' }
    if ((Get-Date) -lt $alpineNextTelemetry) { [void]$alpineProcess.WaitForExit(100); continue }
    $alpineNextTelemetry = (Get-Date).AddSeconds(2)
    $alpineProcess.Refresh()
    # Godot's Windows console executable is a waiting launcher. Measure the
    # child engine, not the launcher's small working set.
    if ($alpineWorker.Id -eq $alpineProcess.Id) {
        $alpineChild = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($alpineProcess.Id)" | Where-Object { $_.Name -like 'Godot*.exe' } | Select-Object -First 1
        if ($alpineChild) { $alpineWorker = Get-Process -Id $alpineChild.ProcessId }
    }
    $alpineWorker.Refresh()
    $alpineOS = Get-CimInstance Win32_OperatingSystem
    $alpineAllGpuRows = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory -ErrorAction SilentlyContinue)
    $alpineGpuRows = @($alpineAllGpuRows | Where-Object { $_.Name -like "pid_$($alpineWorker.Id)_*" })
    $alpineGpuMemory = $null
    if ($alpineGpuRows.Count -gt 0) {
        $alpineGpuMemory = @{dedicated_bytes=($alpineGpuRows | Measure-Object DedicatedUsage -Sum).Sum; shared_bytes=($alpineGpuRows | Measure-Object SharedUsage -Sum).Sum; source='Windows GPU process memory counters'}
    }
    $alpineWoW = @(Get-Process -Name Wow,WowClassic -ErrorAction SilentlyContinue)
    $alpineOtherEngines = @(Get-Process -Name Godot* -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $alpineWorker.Id -and $_.Id -ne $alpineProcess.Id -and $_.ProcessName -notlike '*console*' } | Select-Object Id,CPU,WorkingSet64)
    # Record observed competing CPU work without closing the user's applications.
    # CPU percentages are relative to the whole machine, not a single core.
    $alpineTelemetryNow = [DateTime]::UtcNow
    $alpineTelemetrySeconds = [Math]::Max(0.001,($alpineTelemetryNow-$alpinePreviousTelemetry).TotalSeconds)
    $alpineCurrentCpu = @{}
    $alpineBackground = @(foreach ($alpineExisting in Get-Process) {
        $alpineCurrentCpu[$alpineExisting.Id] = $alpineExisting.CPU
        if ($alpineExisting.Id -in @($alpineWorker.Id,$alpineProcess.Id,0)) { continue }
        $alpineCpuDelta = if ($alpinePreviousCpu.ContainsKey($alpineExisting.Id)) { [Math]::Max(0,$alpineExisting.CPU-$alpinePreviousCpu[$alpineExisting.Id]) } else { 0 }
        if ($alpineCpuDelta -ge 0.01 -or $alpineExisting.WorkingSet64 -ge 512MB) {
            @{pid=$alpineExisting.Id; name=$alpineExisting.ProcessName; cpu_machine_percent=100*$alpineCpuDelta/$alpineTelemetrySeconds/[Environment]::ProcessorCount; working_set_bytes=$alpineExisting.WorkingSet64}
        }
    })
    $alpineBackground = @($alpineBackground | Sort-Object { $_.cpu_machine_percent } -Descending | Select-Object -First 20)
    $alpinePreviousCpu = $alpineCurrentCpu; $alpinePreviousTelemetry = $alpineTelemetryNow
    $alpineOtherGpu = @($alpineAllGpuRows | Where-Object { $_.Name -notlike "pid_$($alpineWorker.Id)_*" -and ($_.DedicatedUsage -ge 64MB -or $_.SharedUsage -ge 64MB) } | Select-Object Name,DedicatedUsage,SharedUsage)
    $alpineSamples.Add(@{utc=$alpineTelemetryNow.ToString('o'); engine_pid=$alpineWorker.Id; working_set_bytes=$alpineWorker.WorkingSet64; private_bytes=$alpineWorker.PrivateMemorySize64; gpu_memory=$alpineGpuMemory; system_free_bytes=[int64]$alpineOS.FreePhysicalMemory*1024; other_godot_processes=$alpineOtherEngines; background_processes=$alpineBackground; other_gpu_allocations=$alpineOtherGpu; wow_running=$alpineWoW.Count -gt 0; wow_working_set_bytes=($alpineWoW | Measure-Object WorkingSet64 -Sum).Sum})
}
$alpineProcess.WaitForExit()
} catch {
    $alpineFailure = $_.Exception.Message
} finally {
    if (-not $alpineProcess.HasExited) { $alpineProcess.Kill($true); $alpineProcess.WaitForExit() }
    foreach ($alpinePump in @($alpineStdout,$alpineStderr)) {
        try { [void]$alpinePump.Completion.GetAwaiter().GetResult() }
        catch { $alpineFailure = "Output capture failed: $($_.Exception.Message)" }
        foreach ($alpineLine in $alpinePump.Drain()) { Write-Output $alpineLine }
        if ($alpinePump.HasEngineError -or $alpinePump.HasTestFailure) { $alpineFailure = 'Engine or test errors in benchmark output.' }
    }
}
$alpineExit = $alpineProcess.ExitCode
if ($alpineFailure) { $alpineExit=1; Write-Output "BENCHMARK_ERROR $alpineFailure" }
$alpineSources = Get-AlpineSourceHashes
$alpineChangedSources = @(@($alpineSources.Keys)+@($alpineSourcesBefore.Keys) | Sort-Object -Unique | Where-Object { $alpineSources[$_] -ne $alpineSourcesBefore[$_] })
@{started_utc=$alpineStarted.ToString('o'); ended_utc=[DateTime]::UtcNow.ToString('o'); exit_code=$alpineExit; project_root=$alpineRoot; engine_path=$alpineEngine; engine_sha256=(Get-FileHash -LiteralPath $alpineEngine).Hash; environment=$alpineEnvironment; cpu=(Get-CimInstance Win32_Processor).Name; installed_ram_bytes=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory; background_policy='Existing apps left untouched. Sample other engines, top 20 active/large processes, and other GPU allocations >=64 MiB every two seconds; GPU allocation is not utilization.'; samples=$alpineSamples; source_sha256_before=$alpineSourcesBefore; source_sha256_after=$alpineSources; changed_sources=$alpineChangedSources} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $alpineOutput 'system.json')
Write-Output "BENCHMARK_COMPLETE $Label exit=$alpineExit"
exit $alpineExit
