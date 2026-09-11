$ErrorActionPreference='Stop'
$deepRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$deepEngine=Join-Path $deepRoot '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe'
foreach($deepTest in @('tests/cascadeur_r8_playtest/physics_suite.gd','tests/cascadeur_r9_playtest/physics_suite.gd','tests/physics_suite.gd','tests/runtime_suite.gd')){
    & $deepEngine --path $deepRoot --headless --script $deepTest
    if($LASTEXITCODE -ne 0){throw "Failed: $deepTest"}
}
& $deepEngine --path $deepRoot 'res://tests/cascadeur_r9_playtest/playtest.tscn' -- --test-lab --ui-staged-loading --cascadeur-snow-ui-check --trial-smoke-exit
if($LASTEXITCODE -ne 0){throw 'Trial startup failed'}
