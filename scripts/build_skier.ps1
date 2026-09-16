$ErrorActionPreference = 'Stop'
$skierRoot = Split-Path $PSScriptRoot -Parent
$skierDependency = Join-Path $skierRoot '.tools/wind/godot-cpp'
$skierDependencyBuild = Join-Path $skierRoot '.tools/wind/build'
$skierLibrary = Join-Path $skierDependencyBuild 'bin/libgodot-cpp.windows.template_debug.x86_64.lib'
if (-not (Test-Path -LiteralPath $skierLibrary)) {
    throw 'Prepare the existing native wind dependency with scripts/build_wind.ps1 first.'
}
$skierBuild = Join-Path $skierRoot '.tools/skier/build'
& cmake -S (Join-Path $skierRoot 'native/skier') -B $skierBuild -G 'Visual Studio 17 2022' -A x64 "-DGODOT_CPP_PATH=$skierDependency" "-DGODOT_CPP_BUILD=$skierDependencyBuild"
if ($LASTEXITCODE) { throw 'Native skier configure failed.' }
& cmake --build $skierBuild --config Release --parallel 2
if ($LASTEXITCODE) { throw 'Native skier build failed.' }
$skierOutput = Join-Path $skierRoot 'addons/alpine_skier/bin'
New-Item -ItemType Directory -Force $skierOutput | Out-Null
Copy-Item -LiteralPath (Join-Path $skierBuild 'Release/alpine_skier.windows.x86_64.dll') -Destination $skierOutput
Get-Item -LiteralPath (Join-Path $skierOutput 'alpine_skier.windows.x86_64.dll') | Select-Object FullName,Length,LastWriteTime
