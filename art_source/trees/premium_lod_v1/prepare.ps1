param(
    [ValidateSet('Build','Bake','Review','Audit')][string]$Mode = 'Review',
    [ValidatePattern('^forest_(spruce|fir|pine|birch|dead|broken|golden|maple)_0[1-4]$')][string]$Asset,
    [switch]$Sample,
    [switch]$Replace,
    [switch]$Resume,
    [string]$Label = 'premium-tree-review'
)
$ErrorActionPreference = 'Stop'
$premiumPack = $PSScriptRoot
$premiumRoot = Split-Path (Split-Path (Split-Path $premiumPack -Parent) -Parent) -Parent
Push-Location -LiteralPath $premiumRoot
try {
    if ($Mode -eq 'Audit') {
        & python (Join-Path $premiumPack 'audit.py')
        if ($LASTEXITCODE -ne 0) { throw 'Premium source audit failed' }
        return
    }
    if ($Mode -eq 'Build') {
        $premiumArgs = @('--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',(Join-Path $premiumPack 'build.py'),'--')
        if ($Asset) { $premiumArgs += @('--asset',$Asset) }
        if ($Sample) { $premiumArgs += '--sample' }
        if ($Replace) { $premiumArgs += '--replace' }
        if ($Resume) { $premiumArgs += '--resume' }
        & ./scripts/run_guarded.ps1 -FilePath 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -Arguments $premiumArgs -Label $Label -TimeoutSeconds 1800 -WorkloadMode Exclusive
    } else {
        $premiumProject = Join-Path $premiumRoot 'artifacts/premium_tree_review/native_project'
        New-Item -ItemType Directory -Force $premiumProject | Out-Null
        @'
config_version=5
[application]
config/name="Alpine Apex premium tree source review"
[display]
window/size/viewport_width=1600
window/size/viewport_height=1000
[rendering]
renderer/rendering_method="forward_plus"
'@ | Set-Content -LiteralPath (Join-Path $premiumProject 'project.godot') -Encoding utf8
        Copy-Item -LiteralPath (Join-Path $premiumPack 'review.gd') -Destination (Join-Path $premiumProject 'review.gd')
        Copy-Item -LiteralPath (Join-Path $premiumPack 'far.gdshader') -Destination (Join-Path $premiumProject 'far.gdshader')
        . ./scripts/resolve_godot_engine.ps1
        $premiumEngine = Get-AlpineGodotEngine -ProjectRoot $premiumRoot -InvocationArguments @('--editor')
        $premiumArgs = @('--path',$premiumProject,'--script','review.gd','--',('--assets='+$premiumPack),('--output='+ (Join-Path $premiumRoot 'artifacts/premium_tree_review/native')))
        if ($Mode -eq 'Bake') { $premiumArgs += @('--bake','--bake-only') }
        if ($Sample) { $premiumArgs += '--sample' }
        & ./scripts/run_guarded.ps1 -FilePath $premiumEngine -Arguments $premiumArgs -Label $Label -TimeoutSeconds 1800 -WorkloadMode Exclusive
        if ($LASTEXITCODE -eq 0 -and $Mode -eq 'Bake') {
            & python (Join-Path $premiumPack 'finish.py')
            if ($LASTEXITCODE -ne 0) { throw 'Atlas sealing failed' }
            & ./scripts/run_guarded.ps1 -FilePath 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -Arguments @('--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',(Join-Path $premiumPack 'finalize_blender.py')) -Label ($Label+'-portable') -TimeoutSeconds 600 -WorkloadMode Exclusive
        }
    }
    if ($LASTEXITCODE -ne 0) { throw "Premium tree $Mode failed: $LASTEXITCODE" }
} finally { Pop-Location }
