# Freeze lightweight project code while other tasks edit the shared workspace.
# Runtime assets and imported resources are shared without copying source libraries.
param([string]$Label = (Get-Date -Format 'yyyyMMdd-HHmmss'))
$ErrorActionPreference = 'Stop'
if ($Label -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid snapshot label.' }
$snapshotSource = Split-Path $PSScriptRoot -Parent
$snapshotRoot = Join-Path $snapshotSource ('.tools/geology_benchmarks/' + $Label)
if (Test-Path -LiteralPath $snapshotRoot) { throw 'Snapshot already exists; choose a new label.' }
New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
$snapshotHashes = @{}
foreach ($folder in @('scripts','config','tests','scenes','addons','examples')) {
    Copy-Item -LiteralPath (Join-Path $snapshotSource $folder) -Destination (Join-Path $snapshotRoot $folder) -Recurse
}
foreach ($file in @('project.godot','main.tscn','icon.svg','icon.svg.import')) {
    Copy-Item -LiteralPath (Join-Path $snapshotSource $file) -Destination (Join-Path $snapshotRoot $file)
}
New-Item -ItemType Directory -Path (Join-Path $snapshotRoot '.godot') | Out-Null
Get-ChildItem -LiteralPath (Join-Path $snapshotSource '.godot') -File -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $snapshotRoot '.godot')
}
# Hash and compare the actual copies before exposing shared resource directories.
Get-ChildItem -LiteralPath $snapshotRoot -Recurse -File -Force | ForEach-Object {
    $relative = $_.FullName.Substring($snapshotRoot.Length + 1)
    $copiedHash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    $sourceHash = (Get-FileHash -LiteralPath (Join-Path $snapshotSource $relative) -Algorithm SHA256).Hash
    if ($copiedHash -ne $sourceHash) { throw "Source changed while copying $relative; this snapshot was not validated." }
    $snapshotHashes[$relative] = $copiedHash
}
foreach ($folder in @('assets','art_source','artifacts','.godot/imported','.godot/shader_cache')) {
    New-Item -ItemType Junction -Path (Join-Path $snapshotRoot $folder) -Target (Join-Path $snapshotSource $folder) | Out-Null
}
@{created_utc=[DateTime]::UtcNow.ToString('o'); source_root=$snapshotSource; snapshot_root=$snapshotRoot; copied_files_sha256=$snapshotHashes; shared_directories=@('assets','art_source','artifacts','.godot/imported','.godot/shader_cache'); note='Copied code is frozen. Shared asset source hashes are checked before and after each benchmark. Runtime output is written to the original artifacts directory.'} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $snapshotRoot 'snapshot.json')
Write-Output $snapshotRoot
