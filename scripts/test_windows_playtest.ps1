param(
    [Parameter(Mandatory)][string]$BuildDirectory,
    [Parameter(Mandatory)][string]$EvidenceDirectory
)
$ErrorActionPreference = 'Stop'
$playtestRoot = Split-Path $PSScriptRoot -Parent
$playtestBuild = (Resolve-Path -LiteralPath $BuildDirectory).Path
$playtestEvidence = [IO.Path]::GetFullPath((Join-Path $playtestRoot $EvidenceDirectory))
if (Test-Path -LiteralPath $playtestEvidence) { throw 'Use a new evidence directory for each empty-profile test.' }
New-Item -ItemType Directory -Force $playtestEvidence | Out-Null
$env:APPDATA = Join-Path $playtestEvidence 'clean_appdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$env:ALPINE_SMOKE_OUT = $playtestEvidence
$playtestArgs = @('--path',('"'+$playtestBuild+'"'),'--windowed','--resolution','1280x720','--log-file',('"'+(Join-Path $playtestEvidence 'godot.log')+'"'),'--script',('"'+(Join-Path $playtestRoot 'tests/windows_playtest_smoke.gd')+'"'),'--','--ui-staged-loading','--benchmark-no-captures')
$playtestProcess = Start-Process -FilePath (Join-Path $playtestBuild 'AlpineApex.exe') -WorkingDirectory $playtestBuild -ArgumentList $playtestArgs -WindowStyle Hidden -Wait -PassThru
if ($playtestProcess.ExitCode -ne 0) { exit $playtestProcess.ExitCode }
if (-not (Test-Path -LiteralPath (Join-Path $playtestEvidence 'results.json'))) { throw 'Game exited without completing the playtest.' }
$playtestErrors = Select-String -LiteralPath (Join-Path $playtestEvidence 'godot.log') -Pattern 'SCRIPT ERROR:|^ERROR:'
if ($playtestErrors) { $playtestErrors | Write-Output; exit 1 }
exit 0
