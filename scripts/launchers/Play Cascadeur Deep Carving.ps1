param([switch]$QuickSlope,[switch]$CheckControls)
$ErrorActionPreference='Stop'
$trialRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $trialRoot 'scripts/resolve_godot_engine.ps1')
$deepCarveEngine=Get-AlpineGodotEngine -ProjectRoot $trialRoot -InvocationArguments @()
$deepCarveArgs=@('--path',$trialRoot,'res://tests/cascadeur_r9_playtest/playtest.tscn','--','--ui-staged-loading')
if($QuickSlope){$deepCarveArgs+='--test-lab'}
if($CheckControls){$deepCarveArgs+='--cascadeur-snow-ui-check'}
& $deepCarveEngine @deepCarveArgs
exit $LASTEXITCODE
