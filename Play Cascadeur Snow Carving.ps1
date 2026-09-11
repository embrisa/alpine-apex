param([switch]$QuickSlope,[switch]$CheckControls)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'scripts/resolve_godot_engine.ps1')
$snowTrialEngine=Get-AlpineGodotEngine -ProjectRoot $PSScriptRoot -InvocationArguments @()
$snowTrialArgs=@('--path',$PSScriptRoot,'res://tests/cascadeur_r8_playtest/playtest.tscn','--','--ui-staged-loading')
if($QuickSlope){$snowTrialArgs+='--test-lab'}
if($CheckControls){$snowTrialArgs+='--cascadeur-snow-ui-check'}
& $snowTrialEngine @snowTrialArgs
exit $LASTEXITCODE
