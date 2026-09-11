param([switch]$QuickSlope,[switch]$CheckControls)
$ErrorActionPreference='Stop'
$trialRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $trialRoot 'scripts/resolve_godot_engine.ps1')
$trialEngine=Get-AlpineGodotEngine -ProjectRoot $trialRoot -InvocationArguments @()
$trialArgs=@('--path',$trialRoot,'res://tests/cascadeur_r7_playtest/playtest.tscn','--','--ui-staged-loading')
if($QuickSlope){$trialArgs+='--test-lab'}
if($CheckControls){$trialArgs+='--cascadeur-ui-check'}
& $trialEngine @trialArgs
exit $LASTEXITCODE
