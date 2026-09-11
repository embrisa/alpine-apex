$ErrorActionPreference='Stop'
$trialProject=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$trialEngine=Join-Path $trialProject '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe'
foreach($trialTest in @('tests/cascadeur_r6_playtest/motion_suite.gd','tests/physics_suite.gd','tests/runtime_suite.gd')) {
    & $trialEngine --path $trialProject --headless --script $trialTest
    if($LASTEXITCODE -ne 0){throw "Regression failed: $trialTest"}
}
