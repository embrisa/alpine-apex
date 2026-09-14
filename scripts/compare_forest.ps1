param(
    [Parameter(Mandatory)][string]$Snapshot,
    [ValidateSet('Prepare','Measure')][string]$Mode='Measure',
    [ValidateSet('all','baseline','candidate')][string]$Arm='all',
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Label='forest_compare'
)
$ErrorActionPreference='Stop'
$forestRoot=Split-Path $PSScriptRoot -Parent
$forestSnapshot=[IO.Path]::GetFullPath($Snapshot,$forestRoot)
if (-not $forestSnapshot.StartsWith((Join-Path $forestRoot 'artifacts')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Snapshot must be under this checkout artifacts.' }
$forestReceipt=Get-Content -LiteralPath (Join-Path $forestSnapshot 'snapshot.json') -Raw | ConvertFrom-Json -AsHashtable
if ($env:ALPINE_VALIDATION_ROOT -ne $forestRoot) {
    if ($Mode -eq 'Measure') {
        # The two projects intentionally share the physical mountain archive.
        # Its scenery slot holds one source revision: warm each arm immediately
        # before measuring, under a separate Exclusive lease.
        $forestArms=if ($Arm -eq 'all') {@('baseline','candidate')} else {@($Arm)}
        foreach ($forestSelected in $forestArms) {
            & (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath pwsh -Arguments @('-NoProfile','-File',$PSCommandPath,'-Snapshot',$forestSnapshot,'-Mode','Prepare','-Arm',$forestSelected,'-Label',$Label) -Label "${Label}_${forestSelected}_prepare" -WorkloadMode Exclusive -TimeoutSeconds 300 -FullMountain -FullMountainReason 'Warm only the frozen forest scenery for the next measured arm; restore existing physical mountain'
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            & (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath pwsh -Arguments @('-NoProfile','-File',$PSCommandPath,'-Snapshot',$forestSnapshot,'-Mode','Measure','-Arm',$forestSelected,'-Label',$Label) -Label "${Label}_${forestSelected}" -WorkloadMode FpsCritical -CollectGpuMemory -TimeoutSeconds 600 -FullMountain -FullMountainReason 'Matched frozen forest rendering with unchanged physical Standard and ordinary inputs'
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
        exit 0
    }
    $forestMode=if ($Mode -eq 'Prepare') {'Exclusive'} else {'FpsCritical'}
    & (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath pwsh -Arguments @('-NoProfile','-File',$PSCommandPath,'-Snapshot',$forestSnapshot,'-Mode',$Mode,'-Arm',$Arm,'-Label',$Label) -Label $Label -WorkloadMode $forestMode -TimeoutSeconds 1200 -FullMountain -FullMountainReason 'Frozen identical physical Standard and input: isolate the nine forest rendering/catalog changes without mutating the shared checkout'
    exit $LASTEXITCODE
}
. (Join-Path $PSScriptRoot 'resolve_godot_engine.ps1')
$forestEngine=Get-AlpineGodotEngine -ProjectRoot $forestRoot
$env:GODOT_BIN=$forestEngine
$forestArms=if ($Arm -eq 'all') {@('baseline','candidate')} else {@($Arm)}
foreach ($forestArm in $forestArms) {
    $forestProject=Join-Path $forestSnapshot $forestArm
    # Hash binaries as well as code: frozen hard-linked inputs cannot drift silently.
    foreach ($forestRelative in $forestReceipt.candidate_source_sha256.Keys) {
        if ($forestRelative.StartsWith('.godot/')) { continue }
        $forestExpected=if ($forestArm -eq 'baseline' -and $forestReceipt.baseline_overrides.ContainsKey($forestRelative)) {$forestReceipt.baseline_overrides[$forestRelative]} else {$forestReceipt.candidate_source_sha256[$forestRelative]}
        if ((Get-FileHash -LiteralPath (Join-Path $forestProject $forestRelative)).Hash.ToLowerInvariant() -cne $forestExpected) { throw "Frozen input changed: $forestArm/$forestRelative" }
    }
    if ($Mode -eq 'Prepare') {
        & $forestEngine --path $forestProject --headless --script res://artifacts/warm_forest.gd
        if ($LASTEXITCODE -ne 0) { throw "Frozen preparation failed: $forestArm" }
        continue
    }
    & (Join-Path $PSScriptRoot 'benchmark_pc.ps1') -ProjectRoot $forestProject -Label "${Label}_${forestArm}" -InputTrace (Join-Path $forestProject $forestReceipt.trace) -ScenarioReplay -TrialStartSeconds 0 -TrialSeconds 15 -Repetitions 3 -FrameCap 120 -Upscaler auto -RenderScale 0.75 -TerrainGI off -FrameGeneration off -ProfileFrameCosts
    if ($LASTEXITCODE -ne 0) { throw "Frozen production measurement failed: $forestArm" }
    $forestProduction=Get-Content -LiteralPath (Join-Path $forestProject "artifacts/pc_environment/${Label}_${forestArm}/production.json") -Raw | ConvertFrom-Json -AsHashtable
    if (-not $forestProduction.loading.scenery_cache_hit) { throw "Scenery cache changed between preparation and timing: $forestArm. Preserve the rejected run and use a fresh label." }
    for ($forestTrial=1; $forestTrial -le 3; $forestTrial++) {
        $forestOutput=Join-Path $forestProject "artifacts/forest_local/$Label/trial-$forestTrial"
        & $forestEngine --path $forestProject --script tests/targeted_performance.gd '--' '--map=perf-vegetation' "--output=$forestOutput" '--seconds=6' '--benchmark-resolution=3840x2160' '--graphics-quality=high' '--render-scale=0.75' '--upscaler=auto' '--fps-limit=120' '--terrain-gi=off' '--frame-generation=off' '--benchmark-no-captures' '--scenery-camera'
        if ($LASTEXITCODE -ne 0) { throw "Frozen local measurement failed: $forestArm/$forestTrial" }
        $forestRow=Get-Content -LiteralPath (Join-Path $forestOutput 'results.json') -Raw | ConvertFrom-Json -AsHashtable
        if ($forestRow.failures.Count -or -not $forestRow.stable_sources -or -not $forestRow.performance_evidence) { throw "Invalid local evidence: $forestArm/$forestTrial" }
    }
    foreach ($forestRelative in $forestReceipt.candidate_source_sha256.Keys) {
        if ($forestRelative.StartsWith('.godot/')) { continue }
        $forestExpected=if ($forestArm -eq 'baseline' -and $forestReceipt.baseline_overrides.ContainsKey($forestRelative)) {$forestReceipt.baseline_overrides[$forestRelative]} else {$forestReceipt.candidate_source_sha256[$forestRelative]}
        if ((Get-FileHash -LiteralPath (Join-Path $forestProject $forestRelative)).Hash.ToLowerInvariant() -cne $forestExpected) { throw "Frozen input changed during measurement: $forestArm/$forestRelative" }
    }
}
Write-Output "FOREST_COMPARISON_COMPLETE mode=$Mode snapshot=$forestSnapshot"
