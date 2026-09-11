# The comparison is always unranked and uses the measured default-v15 fixtures.
$ErrorActionPreference = 'Stop'
$snowProject = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath (Join-Path $snowProject 'artifacts/snow_grounding_v28/mountain.json'))) {
    throw 'Run the guarded snow_grounding_mountain.gd measurement first to prepare the comparison slopes.'
}
Write-Output 'Grounded snow: Resume to ski. F6 compares model 27/28, F7 retries, F8 changes slope. All runs are unranked.'
$snowPlaytestLock = $null
$snowDeadline = (Get-Date).AddMinutes(15)
Write-Output 'Waiting for an idle validation slot before opening the controller comparison.'
while ($null -eq $snowPlaytestLock) {
    if ((Get-Date) -gt $snowDeadline) { throw 'Validation remained busy for 15 minutes; existing workloads were left running.' }
    $snowBusy = @(Get-CimInstance Win32_Process | Where-Object {
        ($_.Name -like 'Godot*.exe' -and $_.CommandLine -match '(--script\s|--import)') -or
        ($_.Name -eq 'blender.exe' -and $_.CommandLine -match '--background')
    })
    if ($snowBusy.Count) { Start-Sleep -Seconds 2; continue }
    try { $snowPlaytestLock = [IO.File]::Open((Join-Path $snowProject 'artifacts/validation.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch [IO.IOException] { Start-Sleep -Seconds 2 }
}
try {
    & (Join-Path $snowProject 'godotw.ps1') --script tests/snow_grounding_playtest.gd '--' --interactive
    $snowPlaytestExit = $LASTEXITCODE
} finally { $snowPlaytestLock.Dispose() }
exit $snowPlaytestExit
