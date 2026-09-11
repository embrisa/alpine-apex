param([switch]$QuickSlope,[switch]$CheckControls)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'scripts/resolve_godot_engine.ps1')
$trialEngine=Get-AlpineGodotEngine -ProjectRoot $PSScriptRoot -InvocationArguments @()
$trialArgs=@('--path',$PSScriptRoot,'res://tests/cascadeur_r7_playtest/playtest.tscn','--','--ui-staged-loading')
if($QuickSlope){$trialArgs+='--test-lab'}
if($CheckControls){$trialArgs+='--cascadeur-ui-check'}
& $trialEngine @trialArgs
exit $LASTEXITCODE
