param()
$ErrorActionPreference = 'Stop'
$fsrRoot = Split-Path $PSScriptRoot -Parent
$fsrSdk = Join-Path $fsrRoot '.tools/FidelityFX-SDK'
$fsrPin = '60f4ea81909200d8542eca14dccb2628b763a9a3'
if (-not (Test-Path -LiteralPath $fsrSdk)) {
    & git clone --no-checkout https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK.git $fsrSdk
    if ($LASTEXITCODE) { throw 'FidelityFX SDK download failed.' }
    & git -C $fsrSdk checkout --detach $fsrPin
    if ($LASTEXITCODE) { throw 'FidelityFX SDK checkout failed.' }
}
$fsrActual = & git -C $fsrSdk rev-parse HEAD
if ($LASTEXITCODE -or $fsrActual -ne $fsrPin) { throw "Expected SDK commit $fsrPin, found $fsrActual. Existing checkout was not modified." }
& git -C $fsrSdk diff --quiet HEAD --
if ($LASTEXITCODE) { throw 'The SDK checkout contains modified tracked files; restore or review it before building.' }
$fsrFiles = @('amd_fidelityfx_loader_dx12.dll', 'amd_fidelityfx_upscaler_dx12.dll', 'amd_fidelityfx_framegeneration_dx12.dll')
$fsrManifest = foreach ($fsrFile in $fsrFiles) {
    $fsrPath = Join-Path $fsrSdk "Kits/FidelityFX/signedbin/$fsrFile"
    $fsrSignature = Get-AuthenticodeSignature -LiteralPath $fsrPath
    if ($fsrSignature.Status -ne 'Valid' -or $fsrSignature.SignerCertificate.Subject -notmatch 'O=Advanced Micro Devices') {
        throw "AMD signature verification failed for $fsrFile : $($fsrSignature.Status)"
    }
    [ordered]@{file=$fsrFile; sha256=(Get-FileHash -LiteralPath $fsrPath -Algorithm SHA256).Hash.ToLowerInvariant(); signer=$fsrSignature.SignerCertificate.Subject; bytes=(Get-Item -LiteralPath $fsrPath).Length}
}
$fsrOutput = Join-Path $fsrRoot 'artifacts/fidelityfx'
New-Item -ItemType Directory -Force $fsrOutput | Out-Null
[ordered]@{sdk='2.3.0'; commit=$fsrPin; path=$fsrSdk; verified_utc=[DateTime]::UtcNow.ToString('o'); files=@($fsrManifest)} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $fsrOutput 'sdk-install.json') -Encoding utf8
Write-Output "Installed AMD FSR SDK 2.3.0 at $fsrSdk; all three runtime DLL signatures verified."
