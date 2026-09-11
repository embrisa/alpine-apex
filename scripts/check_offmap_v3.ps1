param([switch]$Views,[switch]$Quick,[switch]$FixedTiming,[switch]$Descents,[switch]$BoundaryMotion)
$ErrorActionPreference='Stop'
$offmapRoot=Split-Path $PSScriptRoot -Parent
$offmapDeadline=(Get-Date).AddMinutes(20)
do {
    $offmapAvailable=$false
    try {
        $offmapProbe=[IO.File]::Open((Join-Path $offmapRoot 'artifacts/validation.lock'),'OpenOrCreate','ReadWrite','None')
        $offmapProbe.Dispose()
        $offmapBusy=@(Get-CimInstance Win32_Process | Where-Object {($_.Name -like 'Godot*.exe' -and $_.CommandLine -match '(--script\s|--import)') -or ($_.Name -eq 'blender.exe' -and $_.CommandLine -match '--background')})
        $offmapAvailable=$offmapBusy.Count -eq 0
    } catch [IO.IOException] { }
    if (-not $offmapAvailable) { Start-Sleep -Seconds 3 }
} while (-not $offmapAvailable -and (Get-Date) -lt $offmapDeadline)
if (-not $offmapAvailable) { throw 'Existing validation is still active. No native comparison was started.' }
. (Join-Path $PSScriptRoot 'resolve_godot_engine.ps1')
$offmapEngine=Get-AlpineGodotEngine -ProjectRoot $offmapRoot
$offmapTask=if ($Descents) {'tests/offmap_v3_descent.gd'} elseif ($FixedTiming) {'tests/offmap_v3_benchmark.gd'} elseif ($BoundaryMotion) {'tests/offmap_boundary_motion.gd'} else {'tests/offmap_v3_playtest.gd'}
$offmapLabel=if ($Descents) {'offmap_v3_descents'} elseif ($FixedTiming) {'offmap_v3_fixed'} elseif ($BoundaryMotion) {'offmap_v3_boundary_motion'} elseif ($Quick) {'offmap_v3_quick'} else {'offmap_v3_views'}
$offmapArgs=@('--path',$offmapRoot,'--script',$offmapTask,'--','--version=15','--seed=849205174',"--benchmark-label=$offmapLabel",'--benchmark-resolution=3840x2160','--graphics-quality=high','--render-scale=0.75','--upscaler=auto','--fps-limit=120','--terrain-gi=off','--frame-generation=off','--ui-staged-loading')
if (-not $Descents) { $offmapArgs+='--views' }
if ($Quick) { $offmapArgs+='--quick-review' }
if ($Views -and -not $Quick) { $offmapArgs+='--clips' }
if ($Descents) { $offmapArgs+=@('--benchmark-no-captures','--input-trace=res://artifacts/offmap_v3/descent_input.json') }
$offmapBefore=@{}
foreach ($offmapDirectory in @('scripts','tests','config','assets')) {
    Get-ChildItem -LiteralPath (Join-Path $offmapRoot $offmapDirectory) -Recurse -File |
        Where-Object {$_.Extension -in @('.gd','.gdshader','.gdshaderinc','.tres','.res','.json')} |
        ForEach-Object {$offmapBefore[$_.FullName]=(Get-FileHash -LiteralPath $_.FullName).Hash}
}
$offmapStarted=Get-Date
& (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath $offmapEngine -Arguments $offmapArgs -Label $offmapLabel -TimeoutSeconds $(if ($Descents) {2400} else {1200}) -CollectGpuMemory
$offmapExit=$LASTEXITCODE
$offmapChanged=@($offmapBefore.Keys | Where-Object {(Get-FileHash -LiteralPath $_).Hash -ne $offmapBefore[$_]})
$offmapAudit=@{started=$offmapStarted.ToString('o');finished=(Get-Date).ToString('o');exit_code=$offmapExit;engine=$offmapEngine;engine_sha256=(Get-FileHash -LiteralPath $offmapEngine).Hash;cpu=(Get-CimInstance Win32_Processor).Name;ram_bytes=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory;changed_sources=$offmapChanged;source_sha256_before=$offmapBefore;arguments=$offmapArgs}
New-Item -ItemType Directory -Force (Join-Path $offmapRoot "artifacts/pc_environment/$offmapLabel") | Out-Null
$offmapAudit | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $offmapRoot "artifacts/pc_environment/$offmapLabel/system.json")
if ($offmapChanged.Count -and ($FixedTiming -or $Descents)) { throw 'Timing sources changed during the run; repeat on stable sources.' }
exit $offmapExit
