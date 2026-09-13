param([switch]$Worker, [switch]$SkipNative, [switch]$FinalPass,
    [switch]$FullMountain = ($env:ALPINE_FULL_MOUNTAIN -eq '1'),
    [string]$FullMountainReason = $env:ALPINE_FULL_MOUNTAIN_REASON
)
$ErrorActionPreference = 'Stop'
$snowRoot = Split-Path $PSScriptRoot -Parent
if (-not $Worker) {
    # One guard owns the whole serial validation, including every engine child.
    # Queue without interrupting another task or taking its validation lock.
    $snowDeadline = (Get-Date).AddMinutes(30)
    while ($true) {
        $snowLease = $null
        try { $snowLease = [IO.File]::Open((Join-Path $snowRoot 'artifacts/validation.lock'),'OpenOrCreate','ReadWrite','None') }
        catch { if ((Get-Date) -ge $snowDeadline) { throw } }
        if ($snowLease) { $snowLease.Dispose(); break }
        Start-Sleep -Milliseconds 50
    }
    $snowArguments = @('-NoProfile','-File',$PSCommandPath,'-Worker')
    if ($SkipNative) { $snowArguments += '-SkipNative' }
    if ($FinalPass) { $snowArguments += '-FinalPass' }
    $snowLabel = if ($FinalPass) { 'snow_readability_final' } else { 'snow_readability_validation' }
    & "$PSScriptRoot/run_guarded.ps1" -FilePath 'pwsh' -Arguments $snowArguments -Label $snowLabel -TimeoutSeconds 1800 -CollectGpuMemory:(-not $SkipNative) -FullMountain:$FullMountain -FullMountainReason $FullMountainReason
    exit $LASTEXITCODE
}
$snowResults = @()
New-Item -ItemType Directory -Force (Join-Path $snowRoot 'artifacts/snow_readability') | Out-Null
$snowSuites = if ($FinalPass) { @('snow_readability_suite') } else { @('snow_readability_suite','golden_sunlight_suite','pc_graphics_suite') }
foreach ($snowSuite in $snowSuites) {
    $snowArguments = @('--headless','--script',"tests/$snowSuite.gd")
    if ($snowSuite -eq 'snow_readability_suite') { $snowArguments += @('--','--mountain') }
    & "$snowRoot/godotw.ps1" @snowArguments
    $snowCode = $LASTEXITCODE
    $snowResults += @{suite=$snowSuite;exit_code=$snowCode}
    $snowResultFile = if ($FinalPass) { 'final_regression.json' } else { 'regression.json' }
    $snowResults | ConvertTo-Json | Set-Content (Join-Path $snowRoot "artifacts/snow_readability/$snowResultFile")
    if ($snowCode -ne 0) { exit $snowCode }
}
if (-not $SkipNative) {
    $snowNativeArguments = @('--script','tests/snow_readability_playtest.gd','--','--all','--graphics-quality=high','--upscaler=auto','--frame-generation=off','--terrain-gi=off','--render-scale=0.75','--fps-limit=120','--ui-staged-loading')
    if ($FinalPass) { $snowNativeArguments += '--output=res://artifacts/snow_readability/final/visual' }
    & "$snowRoot/godotw.ps1" @snowNativeArguments
    exit $LASTEXITCODE
}
exit 0
