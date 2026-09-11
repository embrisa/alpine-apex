param([int]$Jobs = 6)
$ErrorActionPreference = 'Stop'
$fsrRoot = Split-Path $PSScriptRoot -Parent
$fsrEngine = Join-Path $fsrRoot '.tools/godot-fsr'
$fsrDeps = Join-Path $fsrRoot '.tools/godot-fsr-deps'
& (Join-Path $PSScriptRoot 'install_fidelityfx.ps1')
if (-not (Test-Path -LiteralPath $fsrEngine)) {
    & git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git $fsrEngine
    if ($LASTEXITCODE) { throw 'Godot source download failed.' }
}
New-Item -ItemType Directory -Force $fsrDeps | Out-Null
$fsrPackages = @(
    @{name='mesa-x86_64-msvc';url='https://github.com/godotengine/godot-nir-static/releases/download/25.3.1-3/godot-nir-static-x86_64-msvc-release.zip';check='godot-mesa/VERSION.info'},
    @{name='agility_sdk';url='https://www.nuget.org/api/v2/package/Microsoft.Direct3D.D3D12/1.618.5';check='build/native/include/d3d12.h'}
)
foreach ($fsrPackage in $fsrPackages) {
    $fsrDestination = Join-Path $fsrDeps $fsrPackage.name
    if (-not (Test-Path -LiteralPath $fsrDestination)) {
        $fsrArchive = Join-Path $fsrDeps ($fsrPackage.name+'.zip')
        Invoke-WebRequest -Uri $fsrPackage.url -OutFile $fsrArchive
        Expand-Archive -LiteralPath $fsrArchive -DestinationPath $fsrDestination
    }
}
& python -m SCons --version
if ($LASTEXITCODE) { throw 'Install SCons for the selected Python interpreter before building.' }
& python (Join-Path $PSScriptRoot 'prepare_fidelityfx_engine.py')
if ($LASTEXITCODE) { throw 'Godot renderer patch preparation failed.' }
Push-Location $fsrEngine
try {
    & python -m SCons platform=windows arch=x86_64 target=template_debug disable_path_overrides=no d3d12=yes vulkan=no opengl3=no use_pix=no debug_symbols=no optimize=speed "mesa_libs=$fsrDeps/mesa" "agility_sdk_path=$fsrDeps/agility_sdk" "-j$Jobs"
    if ($LASTEXITCODE) { throw 'Custom Godot build failed.' }
} finally { Pop-Location }
$fsrBin = Join-Path $fsrEngine 'bin'
foreach ($fsrComponent in @('loader','upscaler','framegeneration')) {
    Copy-Item -LiteralPath (Join-Path $fsrRoot ".tools/FidelityFX-SDK/Kits/FidelityFX/signedbin/amd_fidelityfx_${fsrComponent}_dx12.dll") -Destination $fsrBin
}
Copy-Item -LiteralPath (Join-Path $fsrRoot '.tools/FidelityFX-SDK/Kits/FidelityFX/docs/license.md') -Destination (Join-Path $fsrBin 'AMD-FSR-LICENSE.md')
Copy-Item -LiteralPath (Join-Path $fsrEngine 'LICENSE.txt') -Destination (Join-Path $fsrBin 'GODOT-LICENSE.txt')
Write-Output "Custom FSR engine built at $fsrBin"
