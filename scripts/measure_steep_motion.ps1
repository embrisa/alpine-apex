param([switch]$Timing, [ValidatePattern("^[a-zA-Z0-9_-]+$")][string]$Evidence = "steep_motion_gameplay")
# Invoke through run_guarded.ps1 so the complete A/B pair owns one engine slot.
$ErrorActionPreference = 'Stop'
$motionRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $motionRoot
New-Item -ItemType Directory -Force "artifacts/$Evidence" | Out-Null
$motionKind = if ($Timing) { 'timing' } else { 'visual' }
$motionFiles = @(& rg --files scripts config assets/animation assets/graphics | Where-Object {
    $_ -match '\.(gd|gdshader|tres|res)$'
}) + @('project.godot','main.tscn','tests/steep_motion_gameplay.gd','tests/skier_animation_playtest.gd')
$motionHashes = @{}
foreach ($motionFile in $motionFiles) {
    $motionHashes[$motionFile] = (Get-FileHash -LiteralPath $motionFile -Algorithm SHA256).Hash
}
foreach ($motionVariant in @('before','after')) {
    $motionArguments = @('--script','tests/steep_motion_gameplay.gd','--',"--evidence=$Evidence")
    if ($Timing) { $motionArguments += '--timing' }
    if ($motionVariant -eq 'before') { $motionArguments += '--procedural' }
    $motionLog = "artifacts/$Evidence/$motionKind-$motionVariant-final.log"
    & ./godotw.ps1 @motionArguments *> $motionLog
    if ($LASTEXITCODE -ne 0) { throw "$motionVariant $motionKind failed; see $motionLog" }
    if (Select-String -LiteralPath $motionLog -Pattern '^ERROR:|^SCRIPT ERROR:|^FAIL:' -Quiet) {
        throw "$motionVariant $motionKind reported an engine error; see $motionLog"
    }
    foreach ($motionFile in $motionFiles) {
        if ((Get-FileHash -LiteralPath $motionFile -Algorithm SHA256).Hash -ne $motionHashes[$motionFile]) {
            throw "Source changed during the A/B pair: $motionFile"
        }
    }
    Write-Output "$motionVariant $motionKind completed; source hashes stable."
}
@{kind=$motionKind; stable=$true; files=$motionHashes} | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath "artifacts/$Evidence/source-freeze-$motionKind.json"
