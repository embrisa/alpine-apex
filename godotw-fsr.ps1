# Explicit custom-engine entry point. Uses the same project and game arguments.
$ErrorActionPreference = 'Stop'
$fsrEngine = Join-Path $PSScriptRoot '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe'
if (-not (Test-Path -LiteralPath $fsrEngine)) {
    throw 'Build the FidelityFX engine first: ./scripts/build_fidelityfx_engine.ps1'
}
if ($args -contains '--editor' -or $args -contains '-e' -or $args -contains '--import') {
    throw 'The FidelityFX build is a game runtime. Use godotw.ps1 for the stock editor/importer.'
}
& $fsrEngine --path $PSScriptRoot @args
exit $LASTEXITCODE
