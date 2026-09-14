param(
    [Parameter(Mandatory)][string]$Snapshot,
    [ValidateSet('local','standard')][string]$Scope='local',
    [ValidateSet('all','off','dense','sparse')][string]$Gravel='all',
    [switch]$Prepare,
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Label='gravel_compare'
)
$ErrorActionPreference='Stop'
$gravelRoot=Split-Path $PSScriptRoot -Parent
$gravelSnapshot=[IO.Path]::GetFullPath($Snapshot,$gravelRoot)
if (-not $gravelSnapshot.StartsWith((Join-Path $gravelRoot 'artifacts')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Snapshot must be inside artifacts.' }
$gravelReceipt=Get-Content -LiteralPath (Join-Path $gravelSnapshot 'snapshot.json') -Raw | ConvertFrom-Json -AsHashtable
if ($env:ALPINE_VALIDATION_ROOT -ne $gravelRoot) {
    $gravelChild=@('-NoProfile','-File',$PSCommandPath,'-Snapshot',$gravelSnapshot,'-Scope',$Scope,'-Gravel',$Gravel,'-Label',$Label)
    $gravelExtra=@{}
    if ($Prepare) { if ($Scope -ne 'standard') { throw 'Preparation is only for the Standard scenery cache.' }; $gravelChild+='-Prepare' }
    $gravelMode=if ($Prepare) {'Exclusive'} else {'FpsCritical'}
    if ($Scope -eq 'standard') { $gravelExtra=@{FullMountain=$true;FullMountainReason='Matched cosmetic gravel modes on one frozen runtime, unchanged warm Standard and ordinary 15-second input.'} }
    & ./scripts/run_guarded.ps1 -FilePath pwsh -Arguments $gravelChild -Label $Label -WorkloadMode $gravelMode -CollectGpuMemory -TimeoutSeconds 600 @gravelExtra
    exit $LASTEXITCODE
}
if ($env:ALPINE_VALIDATION_MODE -ne $(if ($Prepare) {'Exclusive'} else {'FpsCritical'})) { throw 'Use the required preparation/measurement admission.' }
$gravelProject=Join-Path $gravelSnapshot 'project'
. (Join-Path $PSScriptRoot 'resolve_godot_engine.ps1')
$gravelEngine=Get-AlpineGodotEngine -ProjectRoot $gravelRoot
$env:GODOT_BIN=$gravelEngine # Nested production runner must use this same runtime.
function Assert-GravelInputs {
    foreach ($relative in $gravelReceipt.source_hashes.Keys) {
        if ($relative.StartsWith('.godot/')) { continue }
        if ((Get-FileHash -LiteralPath (Join-Path $gravelProject $relative)).Hash.ToLowerInvariant() -cne $gravelReceipt.source_hashes[$relative]) { throw "Frozen input changed: $relative" }
    }
}
Assert-GravelInputs
if ($Prepare) {
    & $gravelEngine --path $gravelProject --headless --script tests/prepare_gravel_comparison.gd
    if ($LASTEXITCODE -ne 0) { throw 'Frozen scenery preparation failed.' }
} elseif ($Scope -eq 'standard') {
    & ./scripts/benchmark_pc.ps1 -ProjectRoot $gravelProject -Label $Label -InputTrace (Join-Path $gravelProject $gravelReceipt.trace) -ScenarioReplay -TrialStartSeconds 0 -TrialSeconds 15 -Repetitions 3 -FrameCap 120 -Upscaler auto -RenderScale .75 -Grass on -Gravel $Gravel -TerrainGI off -FrameGeneration off -ProfileFrameCosts
    if ($LASTEXITCODE -ne 0) { throw 'Production gravel measurement failed.' }
    $data=Get-Content -LiteralPath (Join-Path $gravelProject "artifacts/pc_environment/$Label/production.json") -Raw | ConvertFrom-Json -AsHashtable
    if (-not $data.loading.scenery_cache_hit) { throw 'Measured scenery cache miss: explicitly prepare the frozen scenery under Exclusive before retrying with a fresh label.' }
} else {
    for ($trial=1;$trial -le 3;$trial++) {
        $destination=Join-Path $gravelProject "artifacts/gravel_local/$Label/trial-$trial"
        & $gravelEngine --path $gravelProject --script tests/targeted_performance.gd -- --map=perf-gravel "--output=$destination" --seconds=6 --benchmark-resolution=3840x2160 --graphics-quality=high --render-scale=0.75 --upscaler=auto --fps-limit=120 --terrain-gi=off --frame-generation=off --benchmark-no-captures --scenery-camera "--gravel=$Gravel"
        if ($LASTEXITCODE -ne 0) { throw "Local gravel trial $trial failed." }
        $row=Get-Content -LiteralPath (Join-Path $destination 'results.json') -Raw | ConvertFrom-Json -AsHashtable
        if ($row.failures.Count -or -not $row.stable_sources -or -not $row.performance_evidence) { throw 'Invalid local evidence.' }
    }
}
Assert-GravelInputs
Write-Output "GRAVEL_COMPARISON_COMPLETE scope=$Scope mode=$Gravel snapshot=$gravelSnapshot"
