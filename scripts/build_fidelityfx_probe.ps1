param([switch]$Run)
$ErrorActionPreference = 'Stop'
$fsrRoot = Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot 'install_fidelityfx.ps1')
$fsrBuild = Join-Path $fsrRoot '.tools/fidelityfx-build'
& cmake -S (Join-Path $fsrRoot 'native/fidelityfx') -B $fsrBuild -G 'Visual Studio 17 2022' -A x64 "-DFIDELITYFX_SDK=$fsrRoot/.tools/FidelityFX-SDK"
if ($LASTEXITCODE) { throw 'FidelityFX probe configuration failed.' }
& cmake --build $fsrBuild --config Release --parallel 4
if ($LASTEXITCODE) { throw 'FidelityFX probe build failed.' }
if ($Run) {
    & (Join-Path $fsrBuild 'Release/fidelityfx_probe.exe') 2>&1 | Tee-Object -FilePath (Join-Path $fsrRoot 'artifacts/fidelityfx/device-probe.log')
    if ($LASTEXITCODE) { throw "FidelityFX device probe failed ($LASTEXITCODE). See artifacts/fidelityfx/device-probe.log." }
}
