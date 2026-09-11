param([switch]$RebuildTextures)
$ErrorActionPreference = 'Stop'
$geologyRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$geologyGodot = Join-Path $geologyRoot 'godotw.ps1'
$geologyBlender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
Push-Location $geologyRoot
try {
    New-Item -ItemType Directory -Force 'artifacts/geology_v11' | Out-Null
    if ($RebuildTextures) {
        & $geologyGodot --headless --script scripts/art/bake_geology_runtime.gd '--' --textures-only
    } else {
        & $geologyGodot --headless --script scripts/art/bake_geology_runtime.gd
    }
    if ($LASTEXITCODE -ne 0) { throw 'Runtime mineral bake failed' }
    & $geologyBlender --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/art/prepare_geology_proxy_meshes.py
    if ($LASTEXITCODE -ne 0) { throw 'Collision input preparation failed' }
    $geologyPython = Join-Path $geologyRoot '.tools/geology-python/Scripts/python.exe'
    if (-not (Test-Path -LiteralPath $geologyPython)) {
        python -m venv .tools/geology-python
        & $geologyPython -m pip install coacd==1.0.14 numpy==2.5.3
        if ($LASTEXITCODE -ne 0) { throw 'Offline collision dependency setup failed' }
    }
    & $geologyPython scripts/art/refine_geology_proxies.py --workers=1 --tolerance=1.0 --fast
    if ($LASTEXITCODE -ne 0) { throw 'Collision refinement failed' }
    python scripts/art/audit_geology_proxies.py
    if ($LASTEXITCODE -ne 0) {
        & $geologyBlender --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/art/repair_geology_voids.py
        if ($LASTEXITCODE -ne 0) { throw 'Source-verified opening correction failed' }
        python scripts/art/audit_geology_proxies.py
        if ($LASTEXITCODE -ne 0) { throw 'Collision opening audit failed' }
    }
    & $geologyBlender --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/art/finish_geology_catalog.py
    if ($LASTEXITCODE -ne 0) { throw 'Collision/footprint preparation failed' }
    python scripts/art/audit_geology_proxies.py
    if ($LASTEXITCODE -ne 0) { throw 'Final collision opening audit failed' }
    & $geologyGodot --headless --script scripts/art/pack_geology_catalog.gd
    if ($LASTEXITCODE -ne 0) { throw 'Runtime catalog packing failed' }
    Copy-Item -LiteralPath 'assets/graphics/minerals_v3/textures/grass.png' -Destination 'assets/graphics/geology_v11/textures/grass.png'
    Copy-Item -LiteralPath 'assets/graphics/minerals_v3/textures/rock_detail.jpg' -Destination 'assets/graphics/geology_v11/textures/rock_detail.jpg'
    python scripts/art/prepare_geology_runtime.py --setup
    if ($LASTEXITCODE -ne 0) { throw 'Import workspace preparation failed' }
    & $geologyGodot --path artifacts/geology_v11/import_project --headless --editor --import
    if ($LASTEXITCODE -ne 0) { throw 'Initial geology import failed' }
    python scripts/art/prepare_geology_runtime.py --configure
    & $geologyGodot --path artifacts/geology_v11/import_project --headless --editor --import
    if ($LASTEXITCODE -ne 0) { throw 'Configured geology import failed' }
    python scripts/art/prepare_geology_runtime.py --sync
    if ($LASTEXITCODE -ne 0) { throw 'Scoped geology cache copy failed' }
    & $geologyGodot --headless --script tests/geology_asset_suite.gd
    if ($LASTEXITCODE -ne 0) { throw 'Runtime geology validation failed' }
} finally { Pop-Location }
