param(
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Label = ('player-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')),
    [string]$Replay = '',
    [switch]$SmokeTest,
    [switch]$FullMountain,
    [string]$FullMountainReason = ''
)
$ErrorActionPreference = 'Stop'
$alpineRoot = Split-Path $PSScriptRoot -Parent
Push-Location $alpineRoot
try {
    if ($Replay) {
        & ./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label',$Label,'-InputTrace',$Replay,'-ScenarioReplay','-Repetitions','1') -Label $Label -TimeoutSeconds 1200 -CollectGpuMemory -FullMountain:$FullMountain -FullMountainReason $FullMountainReason
    } else {
        $alpineOutput = "artifacts/player_recordings/$Label"
        $alpineArgs = @('--script','tests/performance_record.gd','--',"--record-output=$alpineOutput",'--ui-staged-loading','--graphics-quality=high','--upscaler=auto','--render-scale=0.75','--fps-limit=120','--frame-generation=off','--terrain-gi=off','--benchmark-resolution=3840x2160','--benchmark-no-captures')
        if ($SmokeTest) { $alpineArgs += '--record-smoke-test' }
        Write-Output "Recording folder: $alpineOutput"
        Write-Output 'Choose a face and drop in. Triangle / R restarts; D-pad Right / F8 saves a clip. Close the game when finished.'
        & ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments $alpineArgs -Label $Label -TimeoutSeconds 3600 -FullMountain:$FullMountain -FullMountainReason $FullMountainReason
    }
    exit $LASTEXITCODE
} finally { Pop-Location }
