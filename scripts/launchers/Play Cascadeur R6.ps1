param([switch]$QuickSlope,[switch]$CaptureReady)
$ErrorActionPreference='Stop'
$trialRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $trialRoot 'scripts/resolve_godot_engine.ps1')
$trialEngine=Get-AlpineGodotEngine -ProjectRoot $trialRoot -InvocationArguments @()
$trialArgs=@('--path',$trialRoot,'res://tests/cascadeur_r6_playtest/playtest.tscn','--','--ui-staged-loading')
if($QuickSlope){$trialArgs+='--test-lab'}
if($CaptureReady){$trialArgs+='--cascadeur-ready-capture'}
& $trialEngine @trialArgs
exit $LASTEXITCODE
