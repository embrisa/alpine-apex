function Get-AlpineGodotEngine {
    param([string]$ProjectRoot, [string[]]$InvocationArguments = @(), [switch]$MetadataOnly)
    if ($env:GODOT_BIN) { return $env:GODOT_BIN }
    $editorArgs = @($InvocationArguments | Where-Object { $_ -match '^(-e|--editor|--import|--export.*|--doctool|--dump-extension-api|--dump-gdextension-interface)$' })
    $marker = Join-Path $ProjectRoot '.tools/fidelityfx-runtime.json'
    if ($editorArgs.Count -eq 0 -and (Test-Path -LiteralPath $marker)) {
        $selection = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
        $game = Join-Path $ProjectRoot '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.exe'
        $console = Join-Path $ProjectRoot '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe'
        if ($selection.enabled -and (Test-Path -LiteralPath $game) -and (Test-Path -LiteralPath $console)) {
            # Benchmarks record selected paths/versions/stat metadata. Runtime
            # replay/cache compatibility still runs inside the selected engine.
            if ($MetadataOnly) { return $console }
            if ((Get-FileHash -LiteralPath $game).Hash.ToLowerInvariant() -eq $selection.engine_sha256 -and
                (Get-FileHash -LiteralPath $console).Hash.ToLowerInvariant() -eq $selection.console_sha256) { return $console }
        }
    }
    $sharedEditor = Join-Path $ProjectRoot '.tools/godot-editor/Godot_v4.7.2-stable_win64_console.exe'
    if (Test-Path -LiteralPath $sharedEditor) { return $sharedEditor }
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidates = Get-ChildItem -Path "$env:LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot*_console.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($candidates) { return $candidates[0].FullName }
    throw 'Godot was not found. Set GODOT_BIN to the Godot console executable.'
}
