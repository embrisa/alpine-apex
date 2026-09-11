param([ValidateSet('procedural','original')][string]$Mode = 'procedural')
$ErrorActionPreference = 'Stop'
$windRoot = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath (Join-Path $windRoot 'addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll'))) {
    & (Join-Path $PSScriptRoot 'build_wind.ps1') -Test
    if ($LASTEXITCODE) { throw 'Build procedural wind before playing.' }
}
& (Join-Path $windRoot 'godotw.ps1') '--' "--wind-mode=$Mode"
exit $LASTEXITCODE
