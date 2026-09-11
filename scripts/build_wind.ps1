param([ValidateSet('Release','Debug')][string]$Configuration = 'Release', [switch]$Test)
$ErrorActionPreference = 'Stop'
$windRoot = Split-Path $PSScriptRoot -Parent
$windTools = Join-Path $windRoot '.tools/wind'
$windDependency = Join-Path $windTools 'godot-cpp'
$windPin = 'e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77' # Official godot-4.5-stable, compatible with 4.7.2.
New-Item -ItemType Directory -Force $windTools | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $windDependency 'CMakeLists.txt'))) {
    & git clone --depth 1 --branch godot-4.5-stable https://github.com/godotengine/godot-cpp.git $windDependency
    if ($LASTEXITCODE) { throw 'Could not fetch godot-cpp.' }
}
$windActual = & git -C $windDependency rev-parse HEAD
if ($windActual -ne $windPin) { throw "godot-cpp must be pinned to $windPin (found $windActual). Existing dependency directory was not modified." }
$windBuild = Join-Path $windTools 'build'
& cmake -S (Join-Path $windRoot 'native/wind') -B $windBuild -G 'Visual Studio 17 2022' -A x64 "-DGODOT_CPP_PATH=$windDependency"
if ($LASTEXITCODE) { throw 'Wind configure failed.' }
& cmake --build $windBuild --config $Configuration --parallel 4
if ($LASTEXITCODE) { throw 'Wind build failed.' }
if ($Test) {
    & ctest --test-dir $windBuild -C $Configuration --output-on-failure
    if ($LASTEXITCODE) { throw 'Wind DSP tests failed.' }
}
$windBin = Join-Path $windRoot 'addons/alpine_wind/bin'
New-Item -ItemType Directory -Force $windBin | Out-Null
Copy-Item -LiteralPath (Join-Path $windBuild "$Configuration/alpine_wind.windows.x86_64.dll") -Destination $windBin
Get-FileHash -LiteralPath (Join-Path $windBin 'alpine_wind.windows.x86_64.dll') -Algorithm SHA256
