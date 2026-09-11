param([switch]$QuickSlope,[switch]$CheckControls)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'scripts/resolve_godot_engine.ps1')
$deepCarveEngine=Get-AlpineGodotEngine -ProjectRoot $PSScriptRoot -InvocationArguments @()
$deepCarveArgs=@('--path',$PSScriptRoot,'res://tests/cascadeur_r9_playtest/playtest.tscn','--','--ui-staged-loading')
if($QuickSlope){$deepCarveArgs+='--test-lab'}
if($CheckControls){$deepCarveArgs+='--cascadeur-snow-ui-check'}
& $deepCarveEngine @deepCarveArgs
exit $LASTEXITCODE
