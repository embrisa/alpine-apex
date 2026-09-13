param([ValidateSet('procedural','original')][string]$Mode = 'procedural', [switch]$Capture,
    [switch]$FullMountain = ($env:ALPINE_FULL_MOUNTAIN -eq '1'),
    [string]$FullMountainReason = $env:ALPINE_FULL_MOUNTAIN_REASON
)
$ErrorActionPreference = 'Stop'
$windRoot = Split-Path $PSScriptRoot -Parent
$windEngine = $env:GODOT_BIN
if (-not $windEngine) {
    $windEngine = (Get-ChildItem "$env:LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot*_console.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
$windLabel = "wind_$Mode" + $(if ($Capture) { '_capture' } else { '_benchmark' })
$windArgs = @('--path',$windRoot,'--script','tests/wind_descent.gd','--','--version=11','--face=0','--side=-1',
    '--weather=clear',"--wind-mode=$Mode","--benchmark-label=$windLabel",'--benchmark-resolution=3840x2160',
    '--graphics-quality=high','--render-scale=0.75','--upscaler=fsr2','--fps-limit=120','--terrain-gi=off','--ui-staged-loading')
if ($Capture) { $windArgs += '--wind-capture' }
& (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath $windEngine -Arguments $windArgs -Label $windLabel -TimeoutSeconds 900 -CollectGpuMemory -FullMountain:$FullMountain -FullMountainReason $FullMountainReason
exit $LASTEXITCODE
