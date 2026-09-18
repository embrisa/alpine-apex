param([string[]]$Only = @('spruce','fir','pine','birch_bare','maple_bare','dead_snag','broken_tree','birch_summer','maple_summer'))
$ErrorActionPreference = 'Stop'
if ($env:ALPINE_VALIDATION_MODE -ne 'Exclusive') { throw 'Use the Exclusive validation guard.' }
$alpineBlender = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
$alpineSource = 'art_source/trees/meshy_seasons_v1'
$alpinePrepared = 'artifacts/meshy_seasons_20260918/prepared'
foreach ($species in $Only) {
    if ($species -in @('spruce','fir','pine')) {
        $recipe = if ($species -eq 'pine') {'stone_pine'} else {$species}
        $branch = "$alpinePrepared/${species}_slices"
        New-Item -ItemType Directory -Force $branch | Out-Null
        & $alpineBlender --background --factory-startup --python-exit-code 1 --python "$alpineSource/project_bough.py" -- "$alpineSource/${species}_bough_full/source.glb" "$branch/textured.glb"
        if ($LASTEXITCODE) { throw "Branch material bake failed: $species" }
        & $alpineBlender --background --factory-startup --python-exit-code 1 --python art_source/trees/meshy_snow_v1/assemble_bough.py -- "$branch/textured.glb" "$alpinePrepared/$species" --species $recipe --keep-root --mid-outer 320 --mid-inner 96
    } elseif ($species.EndsWith('_summer')) {
        $family = $species.Replace('_summer','')
        $working = "$alpinePrepared/${species}_working"
        $bare = "$alpinePrepared/${family}_bare"
        if (-not (Test-Path -LiteralPath "$bare/tree_lod1.glb")) { throw "Prepare ${family}_bare before its leafy crown." }
        & $alpineBlender --background --factory-startup --python-exit-code 1 --python "$alpineSource/prepare_whole.py" -- "$alpineSource/${species}_full/source.glb" $working --near 40000 --mid 10000
        if ($LASTEXITCODE) { throw "Full-topology source reduction failed: $species" }
        & '.tools/art-venv/Scripts/python.exe' "$alpineSource/compose_leaf_lods.py" "$working/tree_lod0.glb" $bare "$alpinePrepared/$species"
    } else {
        $near = if ($species -in @('dead_snag','broken_tree')) {6000} elseif ($species.EndsWith('_bare')) {14000} else {40000}
        $mid = if ($species -in @('dead_snag','broken_tree')) {1200} elseif ($species.EndsWith('_bare')) {3000} else {10000}
        & $alpineBlender --background --factory-startup --python-exit-code 1 --python "$alpineSource/prepare_whole.py" -- "$alpineSource/$species/source.glb" "$alpinePrepared/$species" --near $near --mid $mid
    }
    if ($LASTEXITCODE) { throw "Source preparation failed: $species" }
}
