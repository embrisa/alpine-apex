param([int]$Port = 8769, [switch]$OpenBrowser)
$ErrorActionPreference = 'Stop'
$reviewRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../artifacts/pose_review'))
$reviewLatest = Get-Content -Raw (Join-Path $reviewRoot 'latest.json') | ConvertFrom-Json
$reviewTarget = [IO.Path]::GetFullPath((Join-Path $reviewRoot $reviewLatest.page))
if (-not $reviewTarget.StartsWith($reviewRoot + [IO.Path]::DirectorySeparatorChar) -or -not (Test-Path -LiteralPath $reviewTarget)) { throw 'Invalid or missing review page.' }
$reviewBase = "http://127.0.0.1:$Port"
$reviewHealth = $null
try { $reviewHealth = Invoke-RestMethod "$reviewBase/__pose_review_health" -TimeoutSec 2 } catch {}
if ($reviewHealth) {
    if ($reviewHealth.service -ne 'alpine-pose-review' -or $reviewHealth.directory -ne $reviewRoot) { throw "Port $Port is used by another service. Choose -Port with a free local port." }
} else {
    $reviewPython = (Get-Command python -ErrorAction Stop).Source
    $reviewScript = Join-Path $PSScriptRoot 'pose_review/serve_review.py'
    $reviewProcess = Start-Process -FilePath $reviewPython -ArgumentList @('-u', ('"'+$reviewScript+'"'), '--root', ('"'+$reviewRoot+'"'), '--port', "$Port") -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $reviewRoot 'server.stdout.log') -RedirectStandardError (Join-Path $reviewRoot 'server.stderr.log')
    for ($reviewTry=0; $reviewTry -lt 30; $reviewTry++) {
        Start-Sleep -Milliseconds 100
        if ($reviewProcess.HasExited) { throw (Get-Content -Raw (Join-Path $reviewRoot 'server.stderr.log')) }
        try { $reviewHealth = Invoke-RestMethod "$reviewBase/__pose_review_health" -TimeoutSec 1; break } catch {}
    }
    if (-not $reviewHealth -or $reviewHealth.service -ne 'alpine-pose-review' -or $reviewHealth.directory -ne $reviewRoot) { throw 'The local review server did not become ready.' }
    @{pid=$reviewProcess.Id;port=$Port;directory=$reviewRoot} | ConvertTo-Json | Set-Content (Join-Path $reviewRoot 'server.json')
}
$reviewUrl = "$reviewBase/" + $reviewLatest.page.Replace('\','/')
if ($OpenBrowser) { Start-Process $reviewUrl }
Write-Output $reviewUrl
