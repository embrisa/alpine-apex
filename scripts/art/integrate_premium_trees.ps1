$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
. ./scripts/resolve_godot_engine.ps1
if ($env:ALPINE_VALIDATION_ROOT -ne (Get-Location).Path) {
    & ./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File',$PSCommandPath) -Label premium_tree_pack -WorkloadMode Exclusive -TimeoutSeconds 900
    exit $LASTEXITCODE
}
if ($env:ALPINE_VALIDATION_MODE -ne 'Exclusive') { throw 'Premium tree resource packing requires Exclusive admission.' }
$premiumEditor = Get-AlpineGodotEngine -ProjectRoot (Get-Location).Path -InvocationArguments @('--editor')
& $premiumEditor --path (Get-Location).Path --rendering-method forward_plus --script scripts/art/integrate_premium_trees.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& python scripts/art/merge_premium_catalog.py
exit $LASTEXITCODE
