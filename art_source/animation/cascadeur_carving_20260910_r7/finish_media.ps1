$ErrorActionPreference='Stop'
# Clothing audit results are retained separately, including the two shared baseline hits.
foreach($mediaStage in @('Videos','Chase')){
    & (Join-Path $PSScriptRoot 'run_review.ps1') -Stage $mediaStage
    if($LASTEXITCODE -ne 0){throw "Media failed at $mediaStage"}
}
