$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$engine=Join-Path $project '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe'
# The first batch completed skier_motion and skier_anatomy before interruption.
foreach($test in @('steep_motion_suite','compact_posture_suite','ski_attachment_suite')) {
    Write-Output "CASCADEUR_TEST_START $test"
    & $engine --path $project --headless --script "tests/$test.gd"
    if($LASTEXITCODE -ne 0){throw "Test failed: $test"}
    Write-Output "CASCADEUR_TEST_COMPLETE $test"
}
