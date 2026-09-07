param(
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Label = 'v7_high_clear',
    [ValidateSet(-1,1)][int]$Side = -1,
    [ValidateSet('clear','snowfall')][string]$Weather = 'clear',
    [ValidateSet(6,7)][int]$Version = 7,
    [string]$RenderScale = '0.75',
    [ValidateSet('native','fsr2')][string]$Upscaler = 'fsr2',
    [ValidateSet(0,90,120,144)][int]$FrameCap = 120,
    [ValidateRange(0,2400)][int]$StartZ = 0,
    [ValidateRange(2450,2850)][int]$EndZ = 2850
)
$ErrorActionPreference = 'Stop'
$alpineRoot = Split-Path $PSScriptRoot -Parent
$alpineEngine = $env:GODOT_BIN
if (-not $alpineEngine) {
    $alpineEngine = (Get-ChildItem "$env:LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot*_console.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not $alpineEngine) { throw 'Set GODOT_BIN to the Godot console executable.' }
$alpineParsedScale = 0.0
if (-not [double]::TryParse($RenderScale,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$alpineParsedScale)) { throw 'Invalid render scale.' }
$alpineOutput = Join-Path $alpineRoot "artifacts/pc_environment/$Label"
New-Item -ItemType Directory -Force $alpineOutput | Out-Null
$alpineArgs = @('--path',('"'+$alpineRoot+'"'),'--script','tests/technical_showcase_playtest.gd','--',"--version=$Version","--side=$Side","--weather=$Weather","--benchmark-label=$Label",'--benchmark-resolution=3840x2160','--graphics-quality=high',"--render-scale=$RenderScale","--upscaler=$Upscaler","--fps-limit=$FrameCap",'--terrain-gi=off','--pov-forest')
$alpineArgs += @("--benchmark-start=$StartZ","--benchmark-end=$EndZ")
$alpineStarted = [DateTime]::UtcNow
function Get-AlpineSourceHashes {
    $alpineHashes = @{}
    foreach ($alpineFolder in @('scripts','config','assets')) {
        Get-ChildItem (Join-Path $alpineRoot $alpineFolder) -Recurse -File | Where-Object { $_.Extension -in @('.gd','.gdshader','.gdshaderinc','.tres','.json') } | ForEach-Object { $alpineHashes[$_.FullName.Substring($alpineRoot.Length+1)] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    }
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
    $alpineWoW = @(Get-Process -Name Wow,WowClassic -ErrorAction SilentlyContinue)
    $alpineSamples.Add(@{utc=[DateTime]::UtcNow.ToString('o'); engine_pid=$alpineWorker.Id; working_set_bytes=$alpineWorker.WorkingSet64; private_bytes=$alpineWorker.PrivateMemorySize64; system_free_bytes=[int64]$alpineOS.FreePhysicalMemory*1024; wow_running=$alpineWoW.Count -gt 0; wow_working_set_bytes=($alpineWoW | Measure-Object WorkingSet64 -Sum).Sum})
    Start-Sleep -Seconds 2
}
$alpineProcess.WaitForExit()
$alpineExit = $alpineProcess.ExitCode
$alpineSources = Get-AlpineSourceHashes
$alpineChangedSources = @($alpineSources.Keys | Where-Object { $alpineSources[$_] -ne $alpineSourcesBefore[$_] })
@{started_utc=$alpineStarted.ToString('o'); ended_utc=[DateTime]::UtcNow.ToString('o'); exit_code=$alpineExit; cpu=(Get-CimInstance Win32_Processor).Name; installed_ram_bytes=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory; background_policy='Existing apps left untouched. WoW is no longer required; actual presence is sampled.'; samples=$alpineSamples; source_sha256_before=$alpineSourcesBefore; source_sha256_after=$alpineSources; changed_sources=$alpineChangedSources} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $alpineOutput 'system.json')
Write-Output "BENCHMARK_COMPLETE $Label exit=$alpineExit"
exit $alpineExit
