param(
    [ValidateSet('Build','Validate','Preview')][string]$Mode = 'Build',
    [ValidateSet('Grass','Plants')][string]$Kind = 'Grass',
    [switch]$Rebuild,
    [switch]$Interactive
)
$ErrorActionPreference = 'Stop'
$grassRoot = Split-Path $PSScriptRoot -Parent
Push-Location -LiteralPath $grassRoot
try {
    $grassKind = $Kind.ToLowerInvariant()
    $grassPackage = if ($Kind -eq 'Grass') { 'grass_v1' } else { 'plants_v1' }
    $grassEvidence = if ($Kind -eq 'Grass') { 'grass_asset_preparation' } else { 'plant_asset_preparation' }
    if ($Mode -in @('Build','Validate')) {
        $grassScript = if ($Mode -eq 'Build') { 'scripts/art/prepare_grass_assets.py' } else { 'scripts/art/validate_grass_assets.py' }
        if ($Mode -eq 'Build' -and $Kind -eq 'Plants') { $grassScript = 'scripts/art/prepare_plant_assets.py' }
        $grassArgs = @('--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',$grassScript)
        if ($Rebuild -and $Mode -eq 'Build') { $grassArgs += @('--','--rebuild') }
        if ($Mode -eq 'Validate') { $grassArgs += @('--','--kind',$grassKind) }
        & ./scripts/run_guarded.ps1 -FilePath 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -Arguments $grassArgs -Label ($grassKind+'-assets-'+$Mode.ToLowerInvariant()) -TimeoutSeconds 300 -OutputMode quiet
    } else {
        $grassPreview = Join-Path $grassRoot ('artifacts/'+$grassEvidence+'/native_project')
        New-Item -ItemType Directory -Force -Path $grassPreview | Out-Null
        @'
config_version=5
[application]
config/name="Prepared grass review"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
'@ | Set-Content -LiteralPath (Join-Path $grassPreview 'project.godot') -Encoding utf8
        Copy-Item -LiteralPath 'scripts/art/preview_grass_assets.gd' -Destination (Join-Path $grassPreview 'preview.gd')
        . ./scripts/resolve_godot_engine.ps1
        $grassEngine = Get-AlpineGodotEngine -ProjectRoot $grassRoot -InvocationArguments @('--editor')
        $grassArgs = @('--path',$grassPreview,'--script','preview.gd','--',
            ('--assets='+(Join-Path $grassRoot ('art_source/foliage/'+$grassPackage))),
            ('--output='+(Join-Path $grassRoot ('artifacts/'+$grassEvidence+'/native'))),('--kind='+$grassKind))
        if ($Interactive) { $grassArgs += '--interactive' }
        & ./scripts/run_guarded.ps1 -FilePath $grassEngine -Arguments $grassArgs -Label ($grassKind+'-assets-preview') -TimeoutSeconds 300
    }
    if ($LASTEXITCODE -ne 0) { throw "Foliage $Kind $Mode failed: $LASTEXITCODE" }
} finally { Pop-Location }
