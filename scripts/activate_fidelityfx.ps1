# Select the custom runtime only after a successful rendered run of this exact binary.
$ErrorActionPreference = 'Stop'
$fsrRoot = Split-Path $PSScriptRoot -Parent
$fsrBin = Join-Path $fsrRoot '.tools/godot-fsr/bin'
$fsrExe = Join-Path $fsrBin 'godot.windows.template_debug.x86_64.exe'
$fsrConsole = Join-Path $fsrBin 'godot.windows.template_debug.x86_64.console.exe'
$fsrReport = Get-Content -LiteralPath (Join-Path $fsrRoot 'artifacts/fidelityfx/render-results.json') -Raw | ConvertFrom-Json
$fsrGuard = Get-Content -LiteralPath (Join-Path $fsrRoot 'artifacts/guarded/fidelityfx_native/guard.json') -Raw | ConvertFrom-Json
$fsrValidation = @(Get-Content -LiteralPath (Join-Path $fsrRoot 'artifacts/fidelityfx/validation.json') -Raw | ConvertFrom-Json)
$fsrGame = Get-Content -LiteralPath (Join-Path $fsrRoot 'artifacts/fidelityfx/game-results.json') -Raw | ConvertFrom-Json
foreach ($fsrCaseName in @('gpu_validation','game','settings','physics','runtime','pc_graphics')) {
    $fsrCheck = @($fsrValidation | Where-Object { $_.name -eq $fsrCaseName })
    if ($fsrCheck.Count -ne 1 -or $fsrCheck[0].exit_code -ne 0 -or $fsrCheck[0].errors.Count -ne 0) {
        throw "Required FidelityFX validation did not pass: $fsrCaseName"
    }
}
if ($fsrGame.failures.Count -ne 0) { throw 'The game scene validation failed.' }
if ($fsrReport.failures.Count -ne 0 -or $fsrGuard.exit_code -ne 0 -or $fsrReport.phases.Count -lt 6) {
    throw 'The native render checks did not complete successfully; the normal launcher was not switched.'
}
$fsrHash = (Get-FileHash -LiteralPath $fsrExe -Algorithm SHA256).Hash.ToLowerInvariant()
if ($fsrReport.executable_sha256 -ne $fsrHash -or [IO.Path]::GetFullPath($fsrReport.executable) -ne [IO.Path]::GetFullPath($fsrExe)) {
    throw 'Rendered evidence does not match the current engine executable.'
}
$fsrSdk = Get-Content -LiteralPath (Join-Path $fsrRoot 'artifacts/fidelityfx/sdk-install.json') -Raw | ConvertFrom-Json
foreach ($fsrFile in $fsrSdk.files) {
    $fsrRuntimeHash = (Get-FileHash -LiteralPath (Join-Path $fsrBin $fsrFile.file) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($fsrRuntimeHash -ne $fsrFile.sha256) { throw "Runtime DLL does not match verified SDK: $($fsrFile.file)" }
}
[ordered]@{
    enabled=$true
    engine_sha256=$fsrHash
    console_sha256=(Get-FileHash -LiteralPath $fsrConsole -Algorithm SHA256).Hash.ToLowerInvariant()
    sdk_commit=$fsrSdk.commit
    activated_utc=[DateTime]::UtcNow.ToString('o')
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fsrRoot '.tools/fidelityfx-runtime.json') -Encoding utf8
Write-Output 'Validated FidelityFX runtime selected for normal game launches. The stock editor/importer remains available.'
