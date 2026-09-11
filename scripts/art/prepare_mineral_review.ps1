param([switch]$ImportOnly, [switch]$Capture, [switch]$Validate)
$ErrorActionPreference = 'Stop'
$detailRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$detailQa = Join-Path $detailRoot 'artifacts/minerals_v3/qa_project'
$detailFolders = @('assets/graphics','scripts/art','scenes/art','tests','artifacts')
foreach ($detailFolder in $detailFolders) {
    New-Item -ItemType Directory -Force -Path (Join-Path $detailQa $detailFolder) | Out-Null
}
# Only this asset pack is mounted. Unrelated source files and editor plugins do
# not participate in the standalone review. Capture output is excluded below.
$detailLinks = @{
    'assets/graphics/minerals' = 'assets/graphics/minerals'
    'assets/graphics/minerals_v3' = 'assets/graphics/minerals_v3'
    'artifacts/minerals_v3' = 'artifacts/minerals_v3'
}
foreach ($detailRelative in $detailLinks.Keys) {
    $detailLink = Join-Path $detailQa $detailRelative
    $detailTarget = Join-Path $detailRoot $detailLinks[$detailRelative]
    if (-not (Test-Path -LiteralPath $detailLink)) {
        New-Item -ItemType Junction -Path $detailLink -Target $detailTarget | Out-Null
    } elseif ((Get-Item -LiteralPath $detailLink).Target -ne $detailTarget) {
        throw "The review mount has an unexpected target: $detailLink"
    }
}
Set-Content -LiteralPath (Join-Path $detailQa 'artifacts/.gdignore') -Value 'Capture output is not a game resource.'
@'
config_version=5
[application]
config/name="Alpine Apex Mineral Detail QA"
run/main_scene="res://scenes/art/mineral_detail_review.tscn"
[display]
window/size/viewport_width=2040
window/size/viewport_height=1020
[rendering]
rendering_device/driver.windows="d3d12"
'@ | Set-Content -LiteralPath (Join-Path $detailQa 'project.godot')
foreach ($detailScript in @('mineral_detail_post_import.gd','mineral_detail_review.gd','mineral_post_import.gd','mineral_gallery.gd','build_mineral_moss_variants.gd','mineral_vegetation_variant.gd')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $detailScript) -Destination (Join-Path $detailQa 'scripts/art')
}
foreach ($detailScene in @('mineral_detail_review.tscn','mineral_gallery.tscn')) {
    Copy-Item -LiteralPath (Join-Path $detailRoot "scenes/art/$detailScene") -Destination (Join-Path $detailQa 'scenes/art')
}
foreach ($detailTest in @('mineral_detail_suite.gd','mineral_vegetation_suite.gd')) {
    Copy-Item -LiteralPath (Join-Path $detailRoot "tests/$detailTest") -Destination (Join-Path $detailQa 'tests')
}
$detailGodot = Join-Path $detailRoot 'godotw.ps1'
& $detailGodot --path $detailQa --headless --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Initial asset import failed.' }
$detailPython = Get-ChildItem -Path 'C:\Program Files\Blender Foundation\Blender*\*\python\bin\python.exe' | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $detailPython) { throw 'Blender Python runtime was not found.' }
& $detailPython.FullName (Join-Path $PSScriptRoot 'configure_mineral_detail_imports.py')
if ($LASTEXITCODE -ne 0) { throw 'Asset import configuration failed.' }
& $detailGodot --path $detailQa --headless --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Configured asset import failed.' }
& $detailPython.FullName (Join-Path $PSScriptRoot 'sync_mineral_import_cache.py')
if ($LASTEXITCODE -ne 0) { throw 'Scoped import cache synchronization failed.' }
if ($Validate) {
    & $detailGodot --path $detailQa --headless --script tests/mineral_detail_suite.gd
    if ($LASTEXITCODE -ne 0) { throw 'Asset validation failed.' }
    & $detailGodot --path $detailQa --headless --script scripts/art/build_mineral_moss_variants.gd
    if ($LASTEXITCODE -ne 0) { throw 'Optional vegetation scene generation failed.' }
    & $detailGodot --path $detailQa --headless --script tests/mineral_vegetation_suite.gd
    if ($LASTEXITCODE -ne 0) { throw 'Optional vegetation validation failed.' }
}
if ($Capture) {
    & $detailGodot --path $detailQa res://scenes/art/mineral_detail_review.tscn '--' --capture
    if ($LASTEXITCODE -ne 0) { throw 'Comparison capture failed.' }
    & $detailGodot --path $detailQa res://scenes/art/mineral_detail_review.tscn '--' --capture --grass
    if ($LASTEXITCODE -ne 0) { throw 'Grass comparison capture failed.' }
    & $detailGodot --path $detailQa res://scenes/art/mineral_gallery.tscn '--' --capture
    if ($LASTEXITCODE -ne 0) { throw 'Library capture failed.' }
} elseif (-not $ImportOnly) {
    & $detailGodot --path $detailQa res://scenes/art/mineral_detail_review.tscn
}
