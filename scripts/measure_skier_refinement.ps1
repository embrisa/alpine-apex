param([switch]$Baseline,[switch]$Timing)
$ErrorActionPreference = 'Stop'
$alpineRoot = Split-Path $PSScriptRoot -Parent
$alpineLabel = $(if ($Baseline) {'before'} else {'after'}) + $(if ($Timing) {'_timing'} else {'_visual'})
$alpineOutput = Join-Path $alpineRoot "artifacts/skier_refinement_v16/$alpineLabel"
New-Item -ItemType Directory -Force -Path $alpineOutput | Out-Null
$alpineEngine = $env:GODOT_BIN
if (-not $alpineEngine) {
    $alpineEngine = (Get-ChildItem "$env:LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot*_console.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not $alpineEngine) { throw 'Set GODOT_BIN to the Godot console executable.' }
$alpineArgs = @('--path',('"'+$alpineRoot+'"'),'--script','tests/skier_refinement_playtest.gd','--','--ui-staged-loading','--graphics-quality=high','--terrain-gi=off')
if ($Baseline) { $alpineArgs += '--baseline-v15' }
if ($Timing) { $alpineArgs += '--timing' }
function Get-RefinementHashes {
    $alpineHashMap = @{}
    $alpineFolders = @('scripts/core','scripts/presentation','scripts/world','config','assets')
    if ($Baseline) { $alpineFolders += 'artifacts/skier_refinement_v16/reference' }
    foreach ($alpineFolder in $alpineFolders) {
        Get-ChildItem -LiteralPath (Join-Path $alpineRoot $alpineFolder) -Recurse -File | Where-Object { $_.Extension -in @('.gd','.tres','.gdshader','.gdshaderinc','.json','.tscn') } | ForEach-Object {
            $alpineHashMap[$_.FullName.Substring($alpineRoot.Length+1)] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
    foreach ($alpineFile in @('scripts/main.gd','tests/skier_refinement_playtest.gd','scripts/measure_skier_refinement.ps1','project.godot','main.tscn')) {
        $alpineHashMap[$alpineFile] = (Get-FileHash -LiteralPath (Join-Path $alpineRoot $alpineFile) -Algorithm SHA256).Hash
    }
    return $alpineHashMap
}
$alpineStarted = [DateTime]::UtcNow
$alpineBefore = Get-RefinementHashes
$alpineProcess = Start-Process -FilePath $alpineEngine -ArgumentList $alpineArgs -WorkingDirectory $alpineRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $alpineOutput 'stdout.log') -RedirectStandardError (Join-Path $alpineOutput 'stderr.log') -PassThru
$alpineWorker = $alpineProcess
$alpineSamples = [Collections.Generic.List[object]]::new()
while (-not $alpineProcess.HasExited) {
    $alpineProcess.Refresh()
    if ($alpineWorker.Id -eq $alpineProcess.Id) {
        $alpineChild = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($alpineProcess.Id)" | Where-Object { $_.Name -like 'Godot*.exe' } | Select-Object -First 1
        if ($alpineChild) { $alpineWorker = Get-Process -Id $alpineChild.ProcessId }
    }
    $alpineWorker.Refresh()
    $alpineOS = Get-CimInstance Win32_OperatingSystem
    $alpineOther = @(Get-Process -Name Godot* -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $alpineProcess.Id -and $_.Id -ne $alpineWorker.Id -and $_.ProcessName -notlike '*console*' } | Select-Object Id,CPU,WorkingSet64)
    $alpineSamples.Add(@{utc=[DateTime]::UtcNow.ToString('o'); engine_pid=$alpineWorker.Id; working_set_bytes=$alpineWorker.WorkingSet64; private_bytes=$alpineWorker.PrivateMemorySize64; system_free_bytes=[int64]$alpineOS.FreePhysicalMemory*1024; other_godot_processes=$alpineOther})
    $alpineErrors = (Get-Content (Join-Path $alpineOutput 'stderr.log') -Tail 24 -ErrorAction SilentlyContinue) -join "`n"
    if ($alpineErrors -match '(?m)^(ERROR:|SCRIPT ERROR:)') {
        # Only the process launched by this script; concurrent agents stay alive.
        Stop-Process -Id $alpineWorker.Id -Force -ErrorAction SilentlyContinue
        break
    }
    Start-Sleep -Seconds 2
}
$alpineProcess.WaitForExit()
$alpineExit = $alpineProcess.ExitCode
$alpineAfter = Get-RefinementHashes
$alpineChanged = @($alpineBefore.Keys | Where-Object { $alpineBefore[$_] -ne $alpineAfter[$_] })
@{label=$alpineLabel; exit_code=$alpineExit; started_utc=$alpineStarted.ToString('o'); ended_utc=[DateTime]::UtcNow.ToString('o'); source_sha256_before=$alpineBefore; source_sha256_after=$alpineAfter; changed_sources=$alpineChanged; process_samples=$alpineSamples; shared_machine=$true} | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $alpineOutput 'system.json')
Write-Output "REFINEMENT_NATIVE_END $alpineLabel exit=$alpineExit"
exit $alpineExit
