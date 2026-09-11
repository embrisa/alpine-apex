# Run once through run_guarded.ps1 so the complete matched pair owns the slot.
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
function Read-HandSources {
    $handMap = @{}
    $handPaths = @(& rg --files scripts config assets/animation assets/graphics -g '*.gd' -g '*.gdshader' -g '*.gdshaderinc' -g '*.tres' -g '*.res' -g '*.glb' -g '*.gdextension')
    if($LASTEXITCODE -ne 0){throw 'Could not enumerate runtime sources'}
    $handPaths += @('project.godot','main.tscn','tests/skier_hands_timing.gd','tests/helpers/skier_hand_comparison.gd','tests/steep_motion_gameplay.gd','tests/skier_animation_playtest.gd','scripts/benchmark_skier_hands.ps1','art_source/meshy/hands_v1/baseline/skier_v7.glb')
    $handPaths += @(Get-ChildItem native -Recurse -File -Filter '*.dll' | ForEach-Object { [IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName) })
    foreach($handPath in $handPaths){ $handMap[$handPath]=(Get-FileHash -LiteralPath $handPath -Algorithm SHA256).Hash }
    return $handMap
}
$handStart = Read-HandSources
$handStart | ConvertTo-Json | Set-Content artifacts/hands_v1/matched_sources_start.json
foreach($handVariant in @('before','after')) {
    $handArgs = @('--script','tests/skier_hands_timing.gd','--','--timing',"--evidence=hands_v1_matched_$handVariant")
    if($handVariant -eq 'before'){ $handArgs += '--hands-baseline' }
    & ./godotw.ps1 @handArgs
    if($LASTEXITCODE -ne 0){ throw "Hand $handVariant timing failed with exit $LASTEXITCODE" }
    $handNow = Read-HandSources
    $handNow | ConvertTo-Json | Set-Content "artifacts/hands_v1/matched_sources_$handVariant.json"
    $handChanged = @((@($handStart.Keys)+@($handNow.Keys)) | Select-Object -Unique | Where-Object { $handStart[$_] -ne $handNow[$_] })
    if($handChanged.Count){ throw ('Sources changed during timing: '+($handChanged -join ', ')) }
}
@{matched=$true;source_changes=@();baseline='hands_v1_matched_before';replacement='hands_v1_matched_after'} | ConvertTo-Json | Set-Content artifacts/hands_v1/matched_timing.json
