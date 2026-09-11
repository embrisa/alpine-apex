param([Parameter(Mandatory)][string]$Payload)
$ErrorActionPreference = 'Stop'
# Do not launch the workload until the parent assigns this helper to its job.
if ([Console]::ReadLine() -ne 'GO') { exit 125 }
$request = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Payload)) | ConvertFrom-Json
Set-Location -LiteralPath $request.directory
$targetArguments = @($request.arguments)
& $request.file @targetArguments
if ($null -ne $LASTEXITCODE) { exit $LASTEXITCODE }
exit 0
