param([switch]$Reference,[ValidateSet(13,14)][int]$Version = 14)
$ErrorActionPreference = 'Stop'
$snowProject = Split-Path $PSScriptRoot -Parent
$snowArgs = @('--script','tests/planted_snow_playtest.gd','--','--interactive',"--version=$Version",'--test-lab')
if ($Reference) {
    if (-not (Test-Path -LiteralPath (Join-Path $snowProject 'artifacts/planted_snow/baseline/core/ski_simulation.gd'))) { throw 'The local v22 comparison snapshot is unavailable.' }
    $snowArgs += '--reference'
}
& "$snowProject/godotw.ps1" @snowArgs
exit $LASTEXITCODE
