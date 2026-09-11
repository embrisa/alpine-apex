param([switch]$Baseline,[switch]$Timing)
$ErrorActionPreference = 'Stop'
$arcadeRoot = Split-Path $PSScriptRoot -Parent
$arcadeLabel = 'arcade_' + $(if($Baseline){'before'}else{'after'}) + $(if($Timing){'_timing'}else{'_visual'})
New-Item -ItemType Directory -Force -Path (Join-Path $arcadeRoot 'artifacts') | Out-Null
if($Baseline){
    & python (Join-Path $PSScriptRoot 'arcade_carving_evidence.py') --prepare-native
    if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
}
$arcadeEngine = $env:GODOT_BIN
if(-not $arcadeEngine){
    $arcadeEngine = (Get-ChildItem "$env:LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot*_console.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if(-not $arcadeEngine){throw 'Set GODOT_BIN to the Godot console executable.'}
$arcadeArgs = @('--path',$arcadeRoot,'--script','tests/arcade_carving_playtest.gd','--','--ui-staged-loading','--graphics-quality=high','--terrain-gi=off')
if($Baseline){$arcadeArgs += '--reference-handling'}
if($Timing){$arcadeArgs += '--timing'}
& (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath $arcadeEngine -Arguments $arcadeArgs -Label $arcadeLabel -TimeoutSeconds 900 -CollectGpuMemory
exit $LASTEXITCODE
