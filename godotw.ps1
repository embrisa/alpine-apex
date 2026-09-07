#!/usr/bin/env pwsh
# Windows counterpart to godotw. GODOT_BIN selects an explicit engine.
# PowerShell consumes a bare -- for scripts. Quote '--' before game arguments:
# ./godotw.ps1 --script tests/technical_showcase_playtest.gd '--' --views
$ErrorActionPreference = 'Stop'
$alpineEngine = $env:GODOT_BIN
if (-not $alpineEngine) {
    $alpineCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($alpineCommand) { $alpineEngine = $alpineCommand.Source }
}
if (-not $alpineEngine) {
    $alpineCandidates = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot*_console.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($alpineCandidates) { $alpineEngine = $alpineCandidates[0].FullName }
}
if (-not $alpineEngine) { throw 'Godot was not found. Set GODOT_BIN to the Godot console executable.' }
& $alpineEngine --path $PSScriptRoot @args
exit $LASTEXITCODE
