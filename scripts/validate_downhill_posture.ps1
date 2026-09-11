param([Parameter(Mandatory)][string]$Output, [switch]$AnimationOnly)
$ErrorActionPreference = 'Stop'
$reviewParent = [IO.DirectoryInfo]::new([IO.Path]::GetFullPath($Output))
while ($null -ne $reviewParent) {
    if (Test-Path -LiteralPath (Join-Path $reviewParent.FullName 'sealed.json')) { throw 'Sealed evidence is read-only; choose a new output folder.' }
    $reviewParent = $reviewParent.Parent
}
if (Test-Path -LiteralPath (Join-Path $Output 'results.json')) { throw 'Results already exist; choose a new output folder.' }
New-Item -ItemType Directory -Path $Output -Force | Out-Null
$results = @()
$suites = @('physics_suite','runtime_suite','skier_anatomy_suite','compact_posture_suite','ski_attachment_suite','skier_motion_suite','landing_absorption_suite','rock_terrain_suite','planted_snow_suite','turn_anatomy_suite')
if ($AnimationOnly) { $suites = @('skier_anatomy_suite','compact_posture_suite','ski_attachment_suite','skier_motion_suite') }
foreach ($suite in $suites) {
    $log = Join-Path $Output "$suite.log"
    & ./godotw.ps1 --headless --script "tests/$suite.gd" *> $log
    $code = $LASTEXITCODE
    $text = Get-Content -LiteralPath $log -Raw
    $ok = $code -eq 0 -and $text -notmatch '(?m)^(SCRIPT ERROR:|ERROR:|FAIL:)'
    $results += [pscustomobject]@{suite=$suite;exit_code=$code;passed=$ok;log=$log}
    Write-Output "DOWNHILL_SUITE $suite passed=$ok exit=$code"
    $results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Output 'results.json')
}
if ($results.passed -contains $false) { exit 1 }
exit 0
