param(
    [ValidateSet('Build','Validate','Preview')][string]$Mode = 'Build',
    [switch]$Rebuild
)
$ErrorActionPreference = 'Stop'
$pebbleRoot = Split-Path $PSScriptRoot -Parent
Push-Location -LiteralPath $pebbleRoot
try {
    if ($Mode -eq 'Build') {
        $pebbleArgs = @('--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python','scripts/art/build_rock_pebbles.py')
        if ($Rebuild) { $pebbleArgs += @('--','--rebuild') }
        & ./scripts/run_guarded.ps1 -FilePath 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -Arguments $pebbleArgs -Label rock-pebble-build -WorkloadMode Exclusive -TimeoutSeconds 180
    } elseif ($Mode -eq 'Validate') {
        & python scripts/art/validate_rock_pebbles.py
    } else {
        $pebblePreview = Join-Path $pebbleRoot 'artifacts/rock_pebble_textures_20260914/native_project'
        New-Item -ItemType Directory -Force -Path $pebblePreview | Out-Null
        @'
config_version=5
[application]
config/name="Cosmetic pebble review"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $pebblePreview 'project.godot') -Encoding utf8
        Copy-Item -LiteralPath 'scripts/art/preview_rock_pebbles.gd' -Destination (Join-Path $pebblePreview 'preview.gd')
        . ./scripts/resolve_godot_engine.ps1
        $pebbleEngine = Get-AlpineGodotEngine -ProjectRoot $pebbleRoot -InvocationArguments @('--editor')
        $pebbleArgs = @('--path',$pebblePreview,'--script','preview.gd','--',
            ('--assets='+(Join-Path $pebbleRoot 'art_source/rocks/pebbles_v1')),
            ('--output='+(Join-Path $pebbleRoot 'artifacts/rock_pebble_textures_20260914/native')))
        & ./scripts/run_guarded.ps1 -FilePath $pebbleEngine -Arguments $pebbleArgs -Label textured-pebble-preview -WorkloadMode Shared -TimeoutSeconds 120
    }
    if ($LASTEXITCODE -ne 0) { throw "Pebble $Mode failed: $LASTEXITCODE" }
} finally { Pop-Location }
