$ErrorActionPreference='Stop'
$snowProject=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$snowEngine=Join-Path $snowProject '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe'
foreach($snowTest in @('tests/cascadeur_r8_playtest/physics_suite.gd','tests/physics_suite.gd','tests/runtime_suite.gd')){
    & $snowEngine --path $snowProject --headless --script $snowTest
    if($LASTEXITCODE -ne 0){throw "Failed: $snowTest"}
}
