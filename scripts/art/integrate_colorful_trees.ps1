param([ValidatePattern('^forest_(golden|maple)_0[1-3]$')][string]$Asset)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
. ./scripts/resolve_godot_engine.ps1
if ($env:ALPINE_VALIDATION_ROOT -ne (Get-Location).Path) {
    $treeChild=@('-NoProfile','-File',$PSCommandPath)
    if ($Asset) { $treeChild+=@('-Asset',$Asset) }
    & ./scripts/run_guarded.ps1 -FilePath pwsh -Arguments $treeChild -Label colorful_tree_pack -WorkloadMode Exclusive -TimeoutSeconds 600
    exit $LASTEXITCODE
}
if ($env:ALPINE_VALIDATION_MODE -ne 'Exclusive') { throw 'Tree resource packing requires Exclusive admission.' }
$treeEditor=Get-AlpineGodotEngine -ProjectRoot (Get-Location).Path -InvocationArguments @('--editor')
$treeArguments=@('--path',(Get-Location).Path,'--rendering-method','forward_plus','--script','scripts/art/integrate_colorful_trees.gd','--')
if ($Asset) { $treeArguments+="--asset=$Asset" }
& $treeEditor @treeArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& python scripts/art/merge_colorful_catalog.py
exit $LASTEXITCODE
