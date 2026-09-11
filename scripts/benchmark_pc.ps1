param(
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Label = 'v15_high_clear',
    [ValidateSet(-1,1)][int]$Side = -1,
    [ValidateSet('clear','snowfall')][string]$Weather = 'clear',
    [ValidateSet(6,7,8,9,10,11,12,13,14,15)][int]$Version = 15,
    [ValidateRange(0,5)][int]$Face = 0,
    [ValidateRange(0,2147483647)][int]$Seed = 849205174,
    [string]$RenderScale = '0.75',
    [ValidateSet('auto','fsr4','fsr3','fsr2','native')][string]$Upscaler = 'auto',
    [ValidateSet('on','off')][string]$TerrainGI = 'off',
    [ValidateSet('on','off')][string]$FrameGeneration = 'off',
    [switch]$ProfileFrameCosts,
    [ValidateRange(1,10)][int]$Repetitions = 1,
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
if ($Version -ge 14) { $alpinePlaytest = 'tests/performance_descent.gd' }
if ($OffmapComparison -or $OffmapBaseline) { $alpinePlaytest = 'tests/offmap_descent.gd' }
if ($OffmapPaired) { $alpinePlaytest = 'tests/offmap_descent_pair.gd' }
if ($WildernessSummit) { $alpinePlaytest = 'tests/wilderness_benchmark.gd' }
if ($VoiceBenchmark) { $alpinePlaytest = 'tests/skier_voice_benchmark.gd' }
$alpineArgs = @('--path',('"'+$alpineRoot+'"'),'--script',$alpinePlaytest,'--',"--version=$Version","--face=$Face","--seed=$Seed","--side=$Side","--weather=$Weather","--benchmark-label=$Label",'--benchmark-resolution=3840x2160','--graphics-quality=high',"--render-scale=$RenderScale","--upscaler=$Upscaler","--fps-limit=$FrameCap","--terrain-gi=$TerrainGI","--frame-generation=$FrameGeneration")
$alpineArgs += @("--benchmark-start=$StartZ","--benchmark-end=$EndZ")
if ($Version -ge 14) { $alpineArgs += @("--input-trace=$InputTrace","--repetitions=$Repetitions",'--benchmark-no-captures') }
elseif (-not $ThirdPerson) { $alpineArgs += '--pov-forest' }
if ($ProfileFrameCosts) { $alpineArgs += '--profile-frame-costs' }
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
        Get-ChildItem (Join-Path $alpineRoot $alpineFolder) -Recurse -File | Where-Object { $_.Extension -in @('.gd','.gdshader','.gdshaderinc','.tres','.tscn','.json') } | ForEach-Object { $alpineHashes[$_.FullName.Substring($alpineRoot.Length+1)] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    }
    $alpineHashes['project.godot'] = (Get-FileHash -LiteralPath (Join-Path $alpineRoot 'project.godot') -Algorithm SHA256).Hash
    $alpineHashes['main.tscn'] = (Get-FileHash -LiteralPath (Join-Path $alpineRoot 'main.tscn') -Algorithm SHA256).Hash
    return $alpineHashes
}
$alpineSourcesBefore = Get-AlpineSourceHashes
$alpineProcess = Start-Process -FilePath $alpineEngine -ArgumentList $alpineArgs -WorkingDirectory $alpineRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $alpineOutput 'stdout.log') -RedirectStandardError (Join-Path $alpineOutput 'stderr.log') -PassThru
$alpineSamples = [Collections.Generic.List[object]]::new()
$alpineWorker = $alpineProcess
while (-not $alpineProcess.HasExited) {
    $alpineProcess.Refresh()
    # Godot's Windows console executable is a waiting launcher. Measure the
    # child engine, not the launcher's small working set.
    if ($alpineWorker.Id -eq $alpineProcess.Id) {
        $alpineChild = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($alpineProcess.Id)" | Where-Object { $_.Name -like 'Godot*.exe' } | Select-Object -First 1
        if ($alpineChild) { $alpineWorker = Get-Process -Id $alpineChild.ProcessId }
    }
    $alpineWorker.Refresh()
    $alpineOS = Get-CimInstance Win32_OperatingSystem
    $alpineGpuRows = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "pid_$($alpineWorker.Id)_*" })
    $alpineGpuMemory = $null
    if ($alpineGpuRows.Count -gt 0) {
        $alpineGpuMemory = @{dedicated_bytes=($alpineGpuRows | Measure-Object DedicatedUsage -Sum).Sum; shared_bytes=($alpineGpuRows | Measure-Object SharedUsage -Sum).Sum; source='Windows GPU process memory counters'}
    }
    $alpineWoW = @(Get-Process -Name Wow,WowClassic -ErrorAction SilentlyContinue)
    $alpineOtherEngines = @(Get-Process -Name Godot* -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $alpineWorker.Id -and $_.Id -ne $alpineProcess.Id -and $_.ProcessName -notlike '*console*' } | Select-Object Id,CPU,WorkingSet64)
    $alpineSamples.Add(@{utc=[DateTime]::UtcNow.ToString('o'); engine_pid=$alpineWorker.Id; working_set_bytes=$alpineWorker.WorkingSet64; private_bytes=$alpineWorker.PrivateMemorySize64; gpu_memory=$alpineGpuMemory; system_free_bytes=[int64]$alpineOS.FreePhysicalMemory*1024; other_godot_processes=$alpineOtherEngines; wow_running=$alpineWoW.Count -gt 0; wow_working_set_bytes=($alpineWoW | Measure-Object WorkingSet64 -Sum).Sum})
    $alpineErrors = (Get-Content (Join-Path $alpineOutput 'stderr.log') -Tail 32 -ErrorAction SilentlyContinue) -join "`n"
    if ($alpineErrors -match '(?m)^(ERROR:|SCRIPT ERROR:)') {
        Stop-Process -Id $alpineWorker.Id -Force -ErrorAction SilentlyContinue
        Write-Error 'Engine errors detected; benchmark stopped.'
    }
    Start-Sleep -Seconds 2
}
$alpineProcess.WaitForExit()
$alpineExit = $alpineProcess.ExitCode
$alpineSources = Get-AlpineSourceHashes
$alpineChangedSources = @(@($alpineSources.Keys)+@($alpineSourcesBefore.Keys) | Sort-Object -Unique | Where-Object { $alpineSources[$_] -ne $alpineSourcesBefore[$_] })
@{started_utc=$alpineStarted.ToString('o'); ended_utc=[DateTime]::UtcNow.ToString('o'); exit_code=$alpineExit; project_root=$alpineRoot; engine_path=$alpineEngine; engine_sha256=(Get-FileHash -LiteralPath $alpineEngine).Hash; cpu=(Get-CimInstance Win32_Processor).Name; installed_ram_bytes=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory; background_policy='Existing apps left untouched. WoW is no longer required; actual presence is sampled.'; samples=$alpineSamples; source_sha256_before=$alpineSourcesBefore; source_sha256_after=$alpineSources; changed_sources=$alpineChangedSources} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $alpineOutput 'system.json')
Write-Output "BENCHMARK_COMPLETE $Label exit=$alpineExit"
exit $alpineExit
