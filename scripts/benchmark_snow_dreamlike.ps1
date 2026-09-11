param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9_-]+$')][string]$Label,
    [ValidateSet('clear','snowfall')][string]$Weather = 'clear'
)
$ErrorActionPreference = 'Stop'
$snowRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
function Get-SnowSources {
    $snowHashes = @{}
    foreach ($snowFolder in @('scripts','config','assets','tests','scenes')) {
        Get-ChildItem -LiteralPath (Join-Path $snowRoot $snowFolder) -Recurse -File | Where-Object { $_.Extension -in @('.gd','.gdshader','.gdshaderinc','.tres','.tscn','.json') } | ForEach-Object {
            $snowHashes[$_.FullName.Substring($snowRoot.Length+1)] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
    foreach ($snowName in @('project.godot','main.tscn')) { $snowHashes[$snowName] = (Get-FileHash -LiteralPath (Join-Path $snowRoot $snowName) -Algorithm SHA256).Hash }
    return $snowHashes
}
$snowSourcesBefore = Get-SnowSources
$snowEngine = (Get-ChildItem "$env:LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot*_console.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$snowOutput = Join-Path $snowRoot "artifacts/pc_environment/$Label"
New-Item -ItemType Directory -Force -Path $snowOutput | Out-Null
$snowArguments = @('--path',('"'+$snowRoot+'"'),'--script','tests/alpine_v13_playtest.gd','--','--views','--terrain-benchmark','--version=13','--seed=849205174',"--benchmark-label=$Label",'--benchmark-resolution=3840x2160','--graphics-quality=high','--upscaler=fsr2','--render-scale=0.75','--fps-limit=120','--terrain-gi=off','--ui-staged-loading',"--weather=$Weather")
$snowStarted = [DateTime]::UtcNow
$snowProcess = Start-Process -FilePath $snowEngine -ArgumentList $snowArguments -WorkingDirectory $snowRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $snowOutput 'stdout.log') -RedirectStandardError (Join-Path $snowOutput 'stderr.log') -PassThru
$snowWorker = $snowProcess
$snowSamples = [Collections.Generic.List[object]]::new()
while (-not $snowProcess.HasExited) {
    if ($snowWorker.Id -eq $snowProcess.Id) {
        $snowChild = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($snowProcess.Id)" | Where-Object { $_.Name -like 'Godot*.exe' } | Select-Object -First 1
        if ($snowChild) { $snowWorker = Get-Process -Id $snowChild.ProcessId }
    }
    $snowWorker.Refresh()
    $snowOS = Get-CimInstance Win32_OperatingSystem
    $snowOther = @(Get-Process -Name Godot* -ErrorAction SilentlyContinue | Where-Object { $_.Id -notin @($snowProcess.Id,$snowWorker.Id) -and $_.ProcessName -notlike '*console*' } | Select-Object Id,CPU,WorkingSet64)
    $snowWow = @(Get-Process -Name Wow,WowClassic -ErrorAction SilentlyContinue)
    $snowSamples.Add(@{utc=[DateTime]::UtcNow.ToString('o'); engine_pid=$snowWorker.Id; private_bytes=$snowWorker.PrivateMemorySize64; working_set_bytes=$snowWorker.WorkingSet64; system_free_bytes=[int64]$snowOS.FreePhysicalMemory*1024; other_godot=$snowOther; wow_running=$snowWow.Count -gt 0; wow_cpu_s=($snowWow | Measure-Object CPU -Sum).Sum})
    Start-Sleep -Seconds 2
}
$snowProcess.WaitForExit()
$snowExit = $snowProcess.ExitCode
$snowSourcesAfter = Get-SnowSources
$snowChanges = @(@($snowSourcesBefore.Keys)+@($snowSourcesAfter.Keys) | Sort-Object -Unique | Where-Object { $snowSourcesBefore[$_] -ne $snowSourcesAfter[$_] })
@{started_utc=$snowStarted.ToString('o'); ended_utc=[DateTime]::UtcNow.ToString('o'); exit_code=$snowExit; weather=$Weather; scope='Twelve four-second real-input ski samples, open snow and forest on all six faces; 120 warmup frames per sample. No capture readback in measured intervals.'; background_policy='Existing applications left untouched; their presence is reported.'; source_sha256_before=$snowSourcesBefore; source_sha256_after=$snowSourcesAfter; changed_sources=$snowChanges; samples=$snowSamples} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $snowOutput 'system.json')
Write-Output "SNOW_BENCHMARK_COMPLETE $Label exit=$snowExit"
exit $snowExit
