param(
    [ValidateSet('Build','Preview','Bake')][string]$Mode = 'Build',
    [ValidatePattern('^(golden_birch|autumn_maple)_0[1-3]$')][string]$Asset,
    [switch]$Interactive
)
$ErrorActionPreference = 'Stop'
$preparedRoot = Split-Path $PSScriptRoot -Parent
Push-Location -LiteralPath $preparedRoot
try {
    if ($Mode -eq 'Build') {
        $preparedArgs = @('--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python','scripts/art/prepare_colorful_trees.py','--')
        if ($Asset) { $preparedArgs += @('--asset', $Asset) }
        & ./scripts/run_guarded.ps1 -FilePath 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -Arguments $preparedArgs -Label colorful-tree-build -TimeoutSeconds 1200
    } else {
        $preparedPreview = Join-Path $preparedRoot 'artifacts/colorful_tree_preparation/native_project'
        New-Item -ItemType Directory -Force -Path $preparedPreview | Out-Null
        @'
config_version=5
[application]
config/name="Prepared tree review"
[rendering]
renderer/rendering_method="forward_plus"
'@ | Set-Content -LiteralPath (Join-Path $preparedPreview 'project.godot') -Encoding utf8
        Copy-Item -LiteralPath 'scripts/art/preview_colorful_trees.gd' -Destination (Join-Path $preparedPreview 'preview.gd')
        . ./scripts/resolve_godot_engine.ps1
        $preparedEngine = Get-AlpineGodotEngine -ProjectRoot $preparedRoot -InvocationArguments @('--editor')
        $preparedArgs = @('--path',$preparedPreview,'--script','preview.gd','--',
            ('--assets=' + (Join-Path $preparedRoot 'art_source/trees/colorful_v1')),
            ('--output=' + (Join-Path $preparedRoot 'artifacts/colorful_tree_preparation/native')))
        if ($Mode -eq 'Bake') { $preparedArgs += '--bake' }
        if ($Interactive) { $preparedArgs += '--interactive' }
        & ./scripts/run_guarded.ps1 -FilePath $preparedEngine -Arguments $preparedArgs -Label colorful-tree-preview -TimeoutSeconds 1200
    }
    if ($LASTEXITCODE -ne 0) { throw "Tree preparation $Mode failed: $LASTEXITCODE" }
} finally { Pop-Location }
