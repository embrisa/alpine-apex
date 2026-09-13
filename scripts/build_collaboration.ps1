param([string]$OutputDirectory = '', [string]$MilestoneNote = '', [switch]$Worker)
$ErrorActionPreference = 'Stop'
$collabRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = 'builds/AlpineApex-Windows-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }
if (-not $Worker) {
    $collabArguments = @('-NoProfile','-File',$PSCommandPath,'-Worker','-OutputDirectory',$OutputDirectory)
    if ($MilestoneNote) { $collabArguments += @('-MilestoneNote',$MilestoneNote) }
    & "$PSScriptRoot/run_guarded.ps1" -WorkloadMode Exclusive -FilePath pwsh -Arguments $collabArguments -Label ('collaboration_export_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) -TimeoutSeconds 1200
    exit $LASTEXITCODE
}

$collabOutput = [IO.Path]::GetFullPath((Join-Path $collabRoot $OutputDirectory))
$collabBuilds = [IO.Path]::GetFullPath((Join-Path $collabRoot 'builds')) + [IO.Path]::DirectorySeparatorChar
if (-not $collabOutput.StartsWith($collabBuilds, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Choose an output directory inside this project''s builds folder.'
}
if ((Test-Path -LiteralPath $collabOutput) -and @(Get-ChildItem -LiteralPath $collabOutput -Force).Count) {
    throw 'The output directory already contains files. Choose a new -OutputDirectory.'
}
$collabRuntime = Join-Path $collabRoot '.tools/godot-fsr/bin'
if (-not (Test-Path -LiteralPath (Join-Path $collabRuntime 'godot.windows.template_debug.x86_64.exe'))) {
    throw 'Run ./scripts/setup_collaboration.ps1 first.'
}

& "$collabRoot/godotw.ps1" --headless --script scripts/prepare_generation_export.gd
if ($LASTEXITCODE) { throw 'Generation dependency preparation failed.' }
New-Item -ItemType Directory -Path $collabOutput -Force | Out-Null
$collabStamp = Join-Path $collabOutput 'build-identity.json'
$collabTarget = Join-Path $collabRuntime 'godot.windows.template_debug.x86_64.exe'
$collabStampArgs = @('stamp','--output',$collabStamp,'--engine',$collabTarget)
if ($MilestoneNote) { $collabStampArgs += @('--note',$MilestoneNote) }
& python "$PSScriptRoot/versioning.py" @collabStampArgs
if ($LASTEXITCODE) { throw 'Development milestone is incomplete; see versioning check output.' }
$collabOldStamp = $env:ALPINE_BUILD_IDENTITY
try {
    $env:ALPINE_BUILD_IDENTITY = $collabStamp
    & "$collabRoot/godotw.ps1" --headless --export-debug 'Windows Playtest' (Join-Path $collabOutput 'AlpineApex.exe')
    if ($LASTEXITCODE) { throw 'Windows export failed.' }
} finally { $env:ALPINE_BUILD_IDENTITY = $collabOldStamp }
& python "$PSScriptRoot/versioning.py" verify-stamp --output $collabStamp --engine $collabTarget
if ($LASTEXITCODE) { throw 'Export source drift; this package is incomplete.' }
& python "$PSScriptRoot/versioning.py" history --output (Join-Path $collabOutput 'CHANGES.md')
if ($LASTEXITCODE) { throw 'Could not generate development change history.' }
foreach ($collabName in @('D3D12Core.dll','amd_fidelityfx_loader_dx12.dll','amd_fidelityfx_upscaler_dx12.dll','amd_fidelityfx_framegeneration_dx12.dll')) {
    Copy-Item -LiteralPath (Join-Path $collabRuntime $collabName) -Destination $collabOutput
}
Copy-Item -LiteralPath "$collabRoot/addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll" -Destination $collabOutput
foreach ($collabName in @('AGILITY-SDK-LICENSE.txt','GODOT_CPP_LICENSE.md','AMD-FSR-LICENSE.md','GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt')) {
    Copy-Item -LiteralPath (Join-Path $collabRoot ('tools/windows/licenses/' + $collabName)) -Destination $collabOutput
}
$collabFiles = @(Get-ChildItem -LiteralPath $collabOutput -File | ForEach-Object {
    @{file=$_.Name; bytes=$_.Length; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
})
@{commit=(& git -C $collabRoot rev-parse HEAD); build=(Get-Content -Raw -LiteralPath $collabStamp | ConvertFrom-Json); files=$collabFiles; prepared_mountain_cache=$false} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $collabOutput 'BUILD.json') -Encoding UTF8
Write-Host "Build ready: $collabOutput\AlpineApex.exe"
