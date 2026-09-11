param(
    [ValidatePattern('^forest_(spruce|fir|pine)_0[1-4]$')][string]$Asset,
    [switch]$BakeNeedles,
    [switch]$Resume
)
$ErrorActionPreference='Stop'
$foliageRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location -LiteralPath $foliageRoot
. ./scripts/resolve_godot_engine.ps1
$foliageBlender='C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
$foliageEditor=Get-AlpineGodotEngine -ProjectRoot $foliageRoot -InvocationArguments @('--editor')
function Invoke-FoliageStage([string]$Executable,[string[]]$StageArguments,[string]$Label) {
    & ./scripts/run_guarded.ps1 -FilePath $Executable -Arguments $StageArguments -Label $Label -TimeoutSeconds 1800
    if ($LASTEXITCODE -ne 0) { throw "Foliage stage failed: $Label" }
}
$foliageBuild=@('--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python','scripts/art/build_tree_collection.py','--')
if ($BakeNeedles) {
    Invoke-FoliageStage $foliageBlender ($foliageBuild+@('--bake-needles')) 'foliage_bake_needles'
    Invoke-FoliageStage $foliageEditor @('--headless','--path',$foliageRoot,'--script','scripts/art/prepare_foliage_textures.gd') 'foliage_pack_textures'
}
$foliageBuild+=if ($Asset) { @('--asset',$Asset) } else { @('--living-only') }
if ($Resume) { $foliageBuild+='--resume' }
Invoke-FoliageStage $foliageBlender $foliageBuild 'foliage_build'
Invoke-FoliageStage $foliageEditor @('--headless','--path',$foliageRoot,'--editor','--import') 'foliage_import'
& python scripts/art/configure_tree_collection_imports.py
if ($LASTEXITCODE -ne 0) { throw 'Foliage import configuration failed' }
Invoke-FoliageStage $foliageEditor @('--headless','--path',$foliageRoot,'--editor','--import') 'foliage_import_configured'
Invoke-FoliageStage $foliageBlender @('--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python','scripts/art/package_tree_collection.py') 'foliage_roundtrip'
