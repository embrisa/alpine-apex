param([string]$ProjectRoot = '', [switch]$NativeOnly,
    [switch]$FullMountain = ($env:ALPINE_FULL_MOUNTAIN -eq '1'),
    [string]$FullMountainReason = $env:ALPINE_FULL_MOUNTAIN_REASON
)
$ErrorActionPreference = 'Stop'
$alpineRoot = Split-Path $PSScriptRoot -Parent
if ($ProjectRoot) { $alpineRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path }
$alpineSuites = if ($NativeOnly) { @('powder_upload_suite','forest_preparation_suite','graphics_suite') } else {
    @('render_efficiency_suite','physics_suite','runtime_suite','pc_graphics_suite','density_lod_suite','density_spatial_suite','fidelityfx_settings_suite','powder_volume_suite')
}
$alpineRows = @()
foreach ($alpineSuite in $alpineSuites) {
    $alpineArgs = @('-NoProfile','-File',(Join-Path $alpineRoot 'godotw.ps1'))
    if (-not $NativeOnly) { $alpineArgs += '--headless' }
    $alpineArgs += @('--script',"tests/$alpineSuite.gd")
    $alpineWaitLogged = $false
    while ($true) {
        try {
            & (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath pwsh -Arguments $alpineArgs -Label "fps_check_$alpineSuite" -TimeoutSeconds 600 -FullMountain:$FullMountain -FullMountainReason $FullMountainReason
            $alpineExit = $LASTEXITCODE
            break
        } catch {
            if ($_.Exception.Message -notmatch 'validation.lock.*being used') { throw }
            if (-not $alpineWaitLogged) { Write-Output "Queued $alpineSuite behind the existing validation."; $alpineWaitLogged = $true }
            Start-Sleep -Milliseconds 250
        }
    }
    $alpineRows += @{suite=$alpineSuite; exit_code=$alpineExit; project=$alpineRoot}
    $alpineOutput = Join-Path (Split-Path $PSScriptRoot -Parent) ('artifacts/fps_optimization/'+$(if ($NativeOnly) {'native_checks.json'} else {'regression_checks.json'}))
    $alpineRows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $alpineOutput
}
if (@($alpineRows | Where-Object {$_.exit_code -ne 0}).Count) { exit 1 }
exit 0
