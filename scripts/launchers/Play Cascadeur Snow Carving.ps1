param([switch]$QuickSlope,[switch]$CheckControls)
$ErrorActionPreference='Stop'
$trialRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $trialRoot 'scripts/resolve_godot_engine.ps1')
$snowTrialEngine=Get-AlpineGodotEngine -ProjectRoot $trialRoot -InvocationArguments @()
$snowTrialArgs=@('--path',$trialRoot,'res://tests/cascadeur_r8_playtest/playtest.tscn','--','--ui-staged-loading')
if($QuickSlope){$snowTrialArgs+='--test-lab'}
if($CheckControls){$snowTrialArgs+='--cascadeur-snow-ui-check'}
& $snowTrialEngine @snowTrialArgs
exit $LASTEXITCODE
