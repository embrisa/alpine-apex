$ErrorActionPreference='Stop'
foreach($reviewStage in @('Audit','Videos','Chase')){
    & (Join-Path $PSScriptRoot 'run_review.ps1') -Stage $reviewStage
    if($LASTEXITCODE -ne 0){throw "Review failed at $reviewStage"}
}
