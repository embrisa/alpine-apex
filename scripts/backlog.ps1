# Forward arguments unchanged to the dependency-free helper (Python 3.10+).
$ErrorActionPreference = 'Stop'
& python (Join-Path $PSScriptRoot 'backlog.py') @args
exit $LASTEXITCODE
