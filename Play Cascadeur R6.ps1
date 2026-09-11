param([switch]$QuickSlope,[switch]$CaptureReady)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'scripts/resolve_godot_engine.ps1')
$trialEngine=Get-AlpineGodotEngine -ProjectRoot $PSScriptRoot -InvocationArguments @()
$trialArgs=@('--path',$PSScriptRoot,'res://tests/cascadeur_r6_playtest/playtest.tscn','--','--ui-staged-loading')
if($QuickSlope){$trialArgs+='--test-lab'}
if($CaptureReady){$trialArgs+='--cascadeur-ready-capture'}
& $trialEngine @trialArgs
exit $LASTEXITCODE
