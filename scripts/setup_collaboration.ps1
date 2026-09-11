param([switch]$SkipImport)
$ErrorActionPreference = 'Stop'
$collabRoot = Split-Path $PSScriptRoot -Parent
$collabManifestPath = Join-Path $collabRoot 'tools/windows/toolchain.json'
$collabManifest = Get-Content -LiteralPath $collabManifestPath -Raw | ConvertFrom-Json
$collabArchive = Join-Path $collabRoot ('tools/windows/' + $collabManifest.archive)

if ((Get-FileHash -LiteralPath $collabArchive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $collabManifest.sha256) {
    throw 'Toolchain archive is missing or differs from its manifest. Run git lfs pull, then retry.'
}

# The archive contains only a pinned editor, validated runtime and their notices.
# Check every entry and digest before installing anything into ignored .tools.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$collabZip = [IO.Compression.ZipFile]::OpenRead($collabArchive)
try {
    if ($collabZip.Entries.Count -ne $collabManifest.files.Count) { throw 'Unexpected toolchain archive entries.' }
    foreach ($collabFile in $collabManifest.files) {
        if ($collabFile.path -notmatch '^\.tools/[a-zA-Z0-9_./-]+$' -or $collabFile.path -match '(^|/)\.\.(/|$)') {
            throw 'Invalid toolchain destination.'
        }
        $collabEntry = $collabZip.GetEntry($collabFile.path)
        if (-not $collabEntry -or $collabEntry.Length -ne $collabFile.bytes) { throw "Missing toolchain entry: $($collabFile.path)" }
        $collabStream = $collabEntry.Open()
        $collabHasher = [Security.Cryptography.SHA256]::Create()
        try { $collabDigest = [BitConverter]::ToString($collabHasher.ComputeHash($collabStream)).Replace('-', '').ToLowerInvariant() }
        finally { $collabStream.Dispose(); $collabHasher.Dispose() }
        if ($collabDigest -ne $collabFile.sha256) { throw "Toolchain digest mismatch: $($collabFile.path)" }
    }
    foreach ($collabFile in $collabManifest.files) {
        $collabTarget = Join-Path $collabRoot $collabFile.path
        if ((Test-Path -LiteralPath $collabTarget) -and
            (Get-FileHash -LiteralPath $collabTarget -Algorithm SHA256).Hash.ToLowerInvariant() -eq $collabFile.sha256) { continue }
        New-Item -ItemType Directory -Path (Split-Path $collabTarget -Parent) -Force | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($collabZip.GetEntry($collabFile.path), $collabTarget, $true)
    }
} finally { $collabZip.Dispose() }

Write-Host 'Pinned Godot editor and Alpine FidelityFX runtime installed and verified.'
if (-not $SkipImport) {
    & (Join-Path $collabRoot 'godotw.ps1') --headless --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot asset import failed; inspect the output above.' }
}
Write-Host 'Run ./godotw.ps1 to play, or ./godotw.ps1 --editor to edit.'
