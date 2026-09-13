param(
    [Parameter(Mandatory)][ValidateSet('Capture','Render','Details','Diagnose','Audit','Regression')][string]$Stage,
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_-]*$')][string]$Revision,
    [string]$Scenarios = 'regular,tuck,prepare_takeoff,carve_left,carve_right,landing',
    [string]$Engine,
    [switch]$Selected,
    [switch]$AnimationOnly,
    [switch]$IncludeFlight,
    [ValidateRange(10,3600)][int]$TimeoutSeconds = 1200,
    [switch]$Describe
,
    [switch]$FullMountain = ($env:ALPINE_FULL_MOUNTAIN -eq '1'),
    [string]$FullMountainReason = $env:ALPINE_FULL_MOUNTAIN_REASON
)
# One guarded workload per call. All paths are resolved from the project, not cwd.
$ErrorActionPreference = 'Stop'
$reviewRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$reviewRelative = "artifacts/pose_review/revisions/$Revision"
$reviewFolder = Join-Path $reviewRoot $reviewRelative
if (Test-Path -LiteralPath (Join-Path $reviewFolder 'sealed.json')) { throw 'Sealed revision: choose a new revision.' }
if ($Stage -ne 'Capture' -and -not (Test-Path -LiteralPath (Join-Path $reviewFolder 'capture/manifest.json'))) { throw 'Capture this revision first.' }
if ($Selected -and $Stage -notin @('Render','Details','Audit')) { throw '-Selected applies only to Render, Details or Audit.' }
if ($AnimationOnly -and $Stage -ne 'Regression') { throw '-AnimationOnly applies only to Regression.' }
if ($IncludeFlight -and $Stage -ne 'Audit') { throw '-IncludeFlight applies only to Audit.' }
$reviewTarget = Join-Path $reviewRoot 'godotw.ps1'
$reviewArgs = @()
switch ($Stage) {
    Capture {
        if (Test-Path -LiteralPath (Join-Path $reviewFolder 'capture/manifest.json')) { throw 'Capture exists: choose a new revision.' }
        $reviewArgs = @('--headless','--script','tests/pose_reference_capture.gd','--','--probe',"--output=$reviewRelative/capture","--scenarios=$Scenarios")
    }
    { $_ -in 'Render','Details','Diagnose' } {
        $reviewArgs = @('--script','tests/pose_reference_render.gd','--',"--revision=$reviewRelative")
        if ($Stage -eq 'Details') { $reviewArgs += '--details' }
        if ($Stage -eq 'Diagnose') { $reviewArgs += '--diagnostic' }
        if ($Selected) { $reviewArgs += '--selected' }
    }
    Audit {
        $reviewArgs = @('--headless','--script','tests/pose_pole_mesh_audit.gd','--',"--revision=$reviewRelative","--scenarios=$Scenarios")
        if ($Selected) { $reviewArgs += '--selected' }
        if ($IncludeFlight) { $reviewArgs += '--include-flight' }
    }
    Regression {
        # Native pwsh parses named script parameters; array-splat strings directly
        # into a parameterized .ps1 would instead bind them as positional values.
        $reviewTarget = (Get-Command pwsh -ErrorAction Stop).Source
        $reviewArgs = @('-NoProfile','-File',(Join-Path $reviewRoot 'scripts/validate_downhill_posture.ps1'),'-Output',"$reviewRelative/regression")
        if ($AnimationOnly) { $reviewArgs += '-AnimationOnly' }
    }
}
if ($Describe) {
    [pscustomobject]@{ stage=$Stage; revision=$Revision; file=$reviewTarget; arguments=$reviewArgs; engine=$Engine; guarded=$true } | ConvertTo-Json -Depth 4
    exit 0
}
$reviewOldEngine = $env:GODOT_BIN
try {
    if ($Engine) { $env:GODOT_BIN = (Get-Item -LiteralPath $Engine -ErrorAction Stop).FullName }
    & (Join-Path $reviewRoot 'scripts/run_guarded.ps1') -FilePath $reviewTarget -Arguments $reviewArgs -Label "pose-$Revision-$Stage" -TimeoutSeconds $TimeoutSeconds -FullMountain:$FullMountain -FullMountainReason $FullMountainReason
    $reviewExit = $LASTEXITCODE
    # Godot can print SCRIPT ERROR while returning zero. Inspect the actual guard logs.
    $reviewLogRoot = Join-Path $reviewRoot "artifacts/guarded/pose-$Revision-$Stage"
    foreach ($reviewLog in @('stdout.log','stderr.log')) {
        $reviewLogPath = Join-Path $reviewLogRoot $reviewLog
        if (Test-Path -LiteralPath $reviewLogPath) {
            if ((Get-Content -LiteralPath $reviewLogPath -Raw) -match '(?m)^(SCRIPT ERROR:|ERROR:|FAIL:)') { $reviewExit = 1 }
        }
    }
    exit $reviewExit
} finally {
    $env:GODOT_BIN = $reviewOldEngine
}
