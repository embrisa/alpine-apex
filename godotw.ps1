#!/usr/bin/env pwsh
# Windows counterpart to godotw. GODOT_BIN selects an explicit engine.
# PowerShell consumes a bare -- for scripts. Quote '--' before game arguments:
# ./godotw.ps1 --script tests/technical_showcase_playtest.gd '--' --views
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot "scripts/resolve_godot_engine.ps1")
$alpineEngine = Get-AlpineGodotEngine -ProjectRoot $PSScriptRoot -InvocationArguments $args
& $alpineEngine --path $PSScriptRoot @args
exit $LASTEXITCODE
