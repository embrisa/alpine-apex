param([string]$Label = 'jump_v13')
$ErrorActionPreference = 'Stop'
$alpineRoot = Split-Path $PSScriptRoot -Parent
$alpineEngine = $env:GODOT_BIN
if (-not $alpineEngine) {
    $alpineEngine = (Get-ChildItem "$env:LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot*_console.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not $alpineEngine) { throw 'Set GODOT_BIN to the Godot console executable.' }
$alpineOutput = Join-Path $alpineRoot 'artifacts/jump_v13/native'
New-Item -ItemType Directory -Force -Path $alpineOutput | Out-Null
$alpineArguments = @('--path',('"'+$alpineRoot+'"'),'--script','tests/airborne_playtest.gd','--','--timing','--graphics-quality=high','--terrain-gi=off')
$alpineSources = @('scripts/core/ski_simulation.gd','scripts/core/rider_body.gd','scripts/core/ski_tuning.gd','scripts/core/landing_assist.gd','scripts/core/rider_facing_pose.gd','scripts/presentation/skier_visual.gd','scripts/presentation/skier_animation.gd','tests/airborne_playtest.gd')
$alpineSources += @('scripts/main.gd','scripts/ui/hud.gd','scripts/presentation/chase_camera.gd','scripts/world/mountain_definition.gd','scripts/world/heightfield_surface.gd','scripts/world/generators/alpine_massif_v10.gd','scripts/world/generators/alpine_face_v10.gd','config/ski_default.tres','project.godot')
function Get-AirborneHashes {
    $alpineHashes = @{}
    foreach ($alpineSource in $alpineSources) { $alpineHashes[$alpineSource] = (Get-FileHash -LiteralPath (Join-Path $alpineRoot $alpineSource)).Hash }
    return $alpineHashes
}
$alpineBefore = Get-AirborneHashes
$alpineStarted = [DateTime]::UtcNow
$alpineProcess = Start-Process -FilePath $alpineEngine -ArgumentList $alpineArguments -WorkingDirectory $alpineRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $alpineOutput 'timing.stdout.log') -RedirectStandardError (Join-Path $alpineOutput 'timing.stderr.log') -PassThru
$alpineWorker = $alpineProcess
$alpineSamples = [Collections.Generic.List[object]]::new()
while (-not $alpineProcess.HasExited) {
    if ($alpineWorker.Id -eq $alpineProcess.Id) {
        $alpineChild = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($alpineProcess.Id)" | Where-Object { $_.Name -like 'Godot*.exe' } | Select-Object -First 1
        if ($alpineChild) { $alpineWorker = Get-Process -Id $alpineChild.ProcessId }
    }
    $alpineWorker.Refresh()
    $alpineOS = Get-CimInstance Win32_OperatingSystem
    $alpineSamples.Add(@{utc=[DateTime]::UtcNow.ToString('o'); working_set_bytes=$alpineWorker.WorkingSet64; private_bytes=$alpineWorker.PrivateMemorySize64; system_free_bytes=[int64]$alpineOS.FreePhysicalMemory*1024})
    Start-Sleep -Seconds 2
    $alpineProcess.Refresh()
}
$alpineProcess.WaitForExit()
$alpineAfter = Get-AirborneHashes
@{label=$Label; started_utc=$alpineStarted.ToString('o'); exit_code=$alpineProcess.ExitCode; cpu=(Get-CimInstance Win32_Processor).Name; samples=$alpineSamples; source_before=$alpineBefore; source_after=$alpineAfter; changed_sources=@($alpineSources | Where-Object { $alpineBefore[$_] -ne $alpineAfter[$_] }); background_policy='Existing applications left untouched; screenshot-free jump fixtures, no simultaneous agent test or encoding workloads.'} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $alpineOutput 'timing.system.json')
Write-Output "AIRBORNE_BENCHMARK_COMPLETE exit=$($alpineProcess.ExitCode)"
exit $alpineProcess.ExitCode
